import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { dataSharePredicates } from '@kit.ArkData'
import { Medium } from '../common/models/Medium'
import { Directory } from '../common/models/Directory'
import { ThumbnailItem } from '../common/models/ThumbnailItem'
import {
  TYPE_IMAGES, TYPE_VIDEOS, TYPE_GIFS, TYPE_RAWS, TYPE_SVGS,
  SORT_BY_NAME, SORT_BY_DATE_MODIFIED, SORT_BY_SIZE, SORT_BY_DATE_TAKEN,
  SORT_BY_RANDOM, SORT_BY_PATH, SORT_DESCENDING,
  RECYCLE_BIN, FAVORITES, LOCATION_INTERNAL
} from '../common/constants/Constants'
import { MediumDao } from '../datastore/dao/MediumDao'
import { FavoritesDao } from '../datastore/dao/FavoritesDao'
import { shouldFolderBeVisible } from '../utils/PathUtils'

// RAW image file extensions recognized by the scanner
const RAW_EXTENSIONS: Array<string> = ['.raw', '.dng', '.cr2', '.nef', '.arw', '.cr3', '.orf', '.raf', '.rw2', '.srw']

// Columns fetched from photoAccessHelper for media assets
const FETCH_COLUMNS: Array<string> = [
  photoAccessHelper.PhotoKeys.URI,
  photoAccessHelper.PhotoKeys.PHOTO_TYPE,
  photoAccessHelper.PhotoKeys.DISPLAY_NAME,
  photoAccessHelper.PhotoKeys.DATE_MODIFIED,
  photoAccessHelper.PhotoKeys.DATE_TAKEN,
  photoAccessHelper.PhotoKeys.SIZE,
  photoAccessHelper.PhotoKeys.DURATION,
  photoAccessHelper.PhotoKeys.TITLE,
  photoAccessHelper.PhotoKeys.FAVORITE  // BUG-034: Read favorite state from system
]

// BUG-031: photoAccessHelper DATE_MODIFIED/DATE_TAKEN return seconds since epoch,
// but JavaScript Date() expects milliseconds. Convert if timestamp looks like seconds.
// Heuristic: timestamps < 20000000000 (year ~2603 in seconds) are in seconds.
function toMilliseconds(ts: number): number {
  if (ts > 0 && ts < 20000000000) {
    return ts * 1000
  }
  return ts
}

export class MediaScanner {
  private context: Context
  private shouldStop: boolean = false
  private scanMutex: boolean = false
  private photoHelper: photoAccessHelper.PhotoAccessHelper
  // BUG-034: Cache of favorite paths from internal DB for fast lookup in assetToMedium
  private favoritePaths: Set<string> = new Set<string>()

  constructor(context: Context) {
    this.context = context
    this.photoHelper = photoAccessHelper.getPhotoAccessHelper(context)
    this.loadFavoritePaths()
  }

  // BUG-034: Load favorite paths from internal FavoritesDao for isFavorite check
  // BUG-034e-fix: Use fast getAllPaths() (not getValidatedPaths) to avoid race condition.
  // Validation/cleanup happens elsewhere (getFavoritesFolder, refreshFavoritesCount).
  private loadFavoritePaths(): void {
    try {
      const favDao: FavoritesDao = new FavoritesDao()
      favDao.getAllPaths().then((paths: Array<string>): void => {
        this.favoritePaths = new Set<string>(paths)
      }).catch((): void => {
        // DB not ready or empty — that's OK
      })
    } catch (e) {
      // DB not initialized yet — will use system FAVORITE flag only
    }
  }

  // FR-001: Get all directories containing media using Albums API
  // BUG-002 fix: HarmonyOS photoAccessHelper URIs (file://media/Photo/xxx) don't contain
  // real folder paths. We must use the Albums API to get actual folder groupings.
  // BUG-012 fix: Hybrid strategy — try USER+ANY, then SYSTEM+ANY, then fall back
  // to grouping all assets by displayName prefix if albums <= 1.
  async getDirectories(filterMedia: number, sorting: number): Promise<Array<Directory>> {
    this.resetStop()
    const directories: Array<Directory> = []
    const addedAlbumUris: Set<string> = new Set<string>()

    try {
      const albumFetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [],
        predicates: new dataSharePredicates.DataSharePredicates()
      }

      // Step 1: Get all user-visible albums with USER + ANY (broader than USER_GENERIC)
      let userAlbumCount: number = 0
      let albumList: photoAccessHelper.FetchResult<photoAccessHelper.Album> | null = null
      try {
        albumList = await this.photoHelper.getAlbums(
            photoAccessHelper.AlbumType.USER,
            photoAccessHelper.AlbumSubtype.ANY,
            albumFetchOptions
          )
        userAlbumCount = albumList.getCount()
        console.info(`MediaScanner: USER+ANY albums found: ${userAlbumCount}`)

        if (userAlbumCount > 0) {
          let album: photoAccessHelper.Album = await albumList.getFirstObject()
          for (let i: number = 0; i < userAlbumCount; i++) {
            if (this.shouldStop) {
              break
            }

            const dirFromAlbum: Directory | null =
              await this.buildDirectoryFromAlbum(album, directories.length, filterMedia)
            if (dirFromAlbum !== null) {
              directories.push(dirFromAlbum)
              addedAlbumUris.add(album.albumUri)
            }

            if (i < userAlbumCount - 1) {
              album = await albumList.getNextObject()
            }
          }
        }
      } catch (albumErr) {
        const e: Error = albumErr as Error
        console.warn(`MediaScanner: USER+ANY albums failed: ${e.message}`)
      } finally {
        if (albumList !== null) {
          try { albumList.close() } catch (e) { /* ignore */ }
        }
      }

      // Step 2: Get system albums (VIDEO, FAVORITE)
      // Note: CAMERA and SCREENSHOT subtypes don't exist in this SDK version (PIT-047)
      // Screenshots will be captured by the fallback grouping in Step 3
      const systemSubtypes: Array<photoAccessHelper.AlbumSubtype> = [
        photoAccessHelper.AlbumSubtype.VIDEO,
        photoAccessHelper.AlbumSubtype.FAVORITE
      ]

      if (!this.shouldStop) {
        for (let st: number = 0; st < systemSubtypes.length; st++) {
          if (this.shouldStop) {
            break
          }
          let sysAlbumList: photoAccessHelper.FetchResult<photoAccessHelper.Album> | null = null
          try {
            sysAlbumList = await this.photoHelper.getAlbums(
                photoAccessHelper.AlbumType.SYSTEM,
                systemSubtypes[st],
                albumFetchOptions
              )
            const sysAlbumCount: number = sysAlbumList.getCount()
            console.info(`MediaScanner: SYSTEM+${st} albums found: ${sysAlbumCount}`)

            if (sysAlbumCount > 0) {
              let sysAlbum: photoAccessHelper.Album = await sysAlbumList.getFirstObject()
              for (let s: number = 0; s < sysAlbumCount; s++) {
                if (this.shouldStop) {
                  break
                }

                // Avoid duplicates
                if (!addedAlbumUris.has(sysAlbum.albumUri)) {
                  const sysDir: Directory | null =
                    await this.buildDirectoryFromAlbum(sysAlbum, directories.length, filterMedia)
                  if (sysDir !== null) {
                    directories.push(sysDir)
                    addedAlbumUris.add(sysAlbum.albumUri)
                  }
                }

                if (s < sysAlbumCount - 1) {
                  sysAlbum = await sysAlbumList.getNextObject()
                }
              }
            }
          } catch (sysErr) {
            const e: Error = sysErr as Error
            console.warn(`MediaScanner: SYSTEM subtype ${st} albums failed: ${e.message}`)
          } finally {
            if (sysAlbumList !== null) {
              try { sysAlbumList.close() } catch (e) { /* ignore */ }
            }
          }
        }
      }

      // Step 3: Add "All Photos" virtual directory at the top of the list.
      // "All photos" = getAssets() directly, not an album.
      if (!this.shouldStop) {
        let allResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null = null
        try {
          const allAssetsFetchOptions: photoAccessHelper.FetchOptions = {
            fetchColumns: [photoAccessHelper.PhotoKeys.SIZE],
            predicates: new dataSharePredicates.DataSharePredicates()
          }
          allResult = await this.photoHelper.getAssets(allAssetsFetchOptions)
          const totalCount: number = allResult.getCount()
          if (totalCount > 0) {
            const firstAsset: photoAccessHelper.PhotoAsset = await allResult.getFirstObject()
            // BUG-015: Translate "All Photos" for display
          const allPhotosName: string = this.getLocalizedGroupName('All Photos')
          const allPhotosDir: Directory = new Directory(
              -1,
              '__all_photos__',
              firstAsset.uri,
              allPhotosName,
              totalCount,
              0,
              0,
              0,
              LOCATION_INTERNAL,
              TYPE_IMAGES | TYPE_VIDEOS,
              ''
            )
            // Insert at the beginning by building a new array
            const withAllPhotos: Array<Directory> = [allPhotosDir]
            for (let ap: number = 0; ap < directories.length; ap++) {
              withAllPhotos.push(directories[ap])
            }
            directories.length = 0
            for (let ap: number = 0; ap < withAllPhotos.length; ap++) {
              directories.push(withAllPhotos[ap])
            }
          }
        } catch (e) {
          console.warn('MediaScanner: Failed to create All Photos directory')
        } finally {
          if (allResult !== null) {
            try { allResult.close() } catch (e) { /* ignore */ }
          }
        }
      }

      // Step 4: Fallback — if albums <= 1 (excluding All Photos), group all assets by displayName prefix
      // This handles devices where the Albums API doesn't return meaningful groupings
      console.info(`MediaScanner: Total album-based directories: ${directories.length}`)
      // Check <= 2 because "All Photos" virtual directory is always present at index 0
      if (directories.length <= 2 && !this.shouldStop) {
        console.info('MediaScanner: Few albums found, falling back to displayName prefix grouping')
        const fallbackDirs: Array<Directory> = await this.buildDirectoriesFromAssetGroups(filterMedia)
        // BUG-019: Count non-"All Photos" dirs for comparison
        const nonAllPhotosCount: number = directories.length > 0 && directories[0].path === '__all_photos__'
          ? directories.length - 1 : directories.length
        if (fallbackDirs.length > nonAllPhotosCount) {
          // BUG-019: Preserve the "All Photos" directory before replacing
          let allPhotosDir: Directory | null = null
          for (let d: number = 0; d < directories.length; d++) {
            if (directories[d].path === '__all_photos__') {
              allPhotosDir = directories[d]
              break
            }
          }
          // Fallback produced more groups — use those instead
          directories.length = 0
          // BUG-019: Re-insert "All Photos" at the beginning
          if (allPhotosDir !== null) {
            directories.push(allPhotosDir)
          }
          for (let f: number = 0; f < fallbackDirs.length; f++) {
            directories.push(fallbackDirs[f])
          }
        }
      }
    } catch (err) {
      const error: Error = err as Error
      console.error('MediaScanner: getDirectories failed: ' + error.message)
    }

    // BUG-019: Sort directories but keep "All Photos" pinned at index 0
    const sorted: Array<Directory> = this.sortDirectories(directories, sorting)
    // Move "All Photos" back to position 0 if it was displaced by sorting
    for (let idx: number = 1; idx < sorted.length; idx++) {
      if (sorted[idx].path === '__all_photos__') {
        const allPhotos: Directory = sorted[idx]
        // Shift elements right to make room at position 0
        for (let j: number = idx; j > 0; j--) {
          sorted[j] = sorted[j - 1]
        }
        sorted[0] = allPhotos
        break
      }
    }
    return sorted
  }

  // BUG-012: Fallback directory grouping — fetch all assets and group by displayName prefix.
  // Groups photos by filename pattern: "IMG_" -> Camera, "screenshot" -> Screenshots, etc.
  // Assets that don't match known prefixes are grouped as "Other".
  private async buildDirectoriesFromAssetGroups(filterMedia: number): Promise<Array<Directory>> {
    const groups: Map<string, Array<photoAccessHelper.PhotoAsset>> = new Map()

    let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null = null
    try {
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: FETCH_COLUMNS,
        predicates: new dataSharePredicates.DataSharePredicates()
      }
      fetchResult = await this.photoHelper.getAssets(fetchOptions)
      const count: number = fetchResult.getCount()
      console.info(`MediaScanner: Fallback grouping — total assets: ${count}`)

      if (count <= 0) {
        return []
      }

      let asset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject()
      for (let i: number = 0; i < count; i++) {
        if (this.shouldStop) {
          break
        }

        if (this.matchesFilter(asset.photoType, asset.displayName, filterMedia)) {
          const groupName: string = this.getGroupNameFromDisplayName(asset.displayName, asset.photoType)

          if (!groups.has(groupName)) {
            groups.set(groupName, [])
          }
          const groupAssets: Array<photoAccessHelper.PhotoAsset> = groups.get(groupName)!
          groupAssets.push(asset)
        }

        if (i < count - 1) {
          asset = await fetchResult.getNextObject()
        }
      }
    } catch (err) {
      const error: Error = err as Error
      console.error(`MediaScanner: buildDirectoriesFromAssetGroups failed: ${error.message}`)
      return []
    } finally {
      if (fetchResult !== null) {
        try {
          fetchResult.close()
        } catch (closeErr) {
          // Ignore close failure
        }
      }
    }

    // Convert groups into Directory objects
    const directories: Array<Directory> = []
    const groupNames: Array<string> = Array.from(groups.keys())
    console.info(`MediaScanner: Fallback produced ${groupNames.length} groups: ${groupNames.join(', ')}`)

    for (let g: number = 0; g < groupNames.length; g++) {
      const groupName: string = groupNames[g]
      const assets: Array<photoAccessHelper.PhotoAsset> = groups.get(groupName)!

      let coverUri: string = ''
      let fallbackCoverUri: string = ''
      let totalSize: number = 0
      let latestModified: number = 0
      let latestTaken: number = 0
      let mediaTypes: number = 0

      for (let a: number = 0; a < assets.length; a++) {
        const asset: photoAccessHelper.PhotoAsset = assets[a]

        // Prefer image assets as cover (they render reliably in Image component)
        // For video-only groups, fall back to first video URI
        if (fallbackCoverUri.length === 0) {
          fallbackCoverUri = asset.uri
        }
        if (coverUri.length === 0 && asset.photoType !== photoAccessHelper.PhotoType.VIDEO) {
          coverUri = asset.uri
        }

        let mod: number = 0
        let tak: number = 0
        let sz: number = 0
        try {
          mod = toMilliseconds((asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number) || 0)
          tak = toMilliseconds((asset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN) as number) || 0)
          sz = (asset.get(photoAccessHelper.PhotoKeys.SIZE) as number) || 0
        } catch (e) {
          // Fallback to defaults
        }

        totalSize += sz
        if (mod > latestModified) {
          latestModified = mod
        }
        if (tak > latestTaken) {
          latestTaken = tak
        }

        if (asset.photoType === photoAccessHelper.PhotoType.VIDEO) {
          mediaTypes = mediaTypes | TYPE_VIDEOS
        } else {
          mediaTypes = mediaTypes | TYPE_IMAGES
        }
      }

      // If no image asset found for cover, use the first video URI as fallback
      if (coverUri.length === 0) {
        coverUri = fallbackCoverUri
      }

      // Use a virtual path prefix so fetchMediaForPath can identify fallback groups
      const virtualPath: string = `__group__:${groupName}`

      // BUG-015: Translate the group name for display
      const localizedName: string = this.getLocalizedGroupName(groupName)

      const dir: Directory = new Directory(
        g,
        virtualPath,
        coverUri,
        localizedName,
        assets.length,
        latestModified,
        latestTaken,
        totalSize,
        LOCATION_INTERNAL,
        mediaTypes,
        ''
      )
      directories.push(dir)
    }

    return directories
  }

  // BUG-015: Translate group names using resource manager
  private getLocalizedGroupName(groupKey: string): string {
    try {
      const resManager = this.context.resourceManager
      const keyMap: Map<string, string> = new Map<string, string>()
      keyMap.set('Camera', 'folder_camera')
      keyMap.set('Camera Videos', 'folder_camera_videos')
      keyMap.set('Videos', 'folder_videos')
      keyMap.set('Screenshots', 'folder_screenshots')
      keyMap.set('Screen Recordings', 'folder_screen_recordings')
      keyMap.set('Downloads', 'folder_downloads')
      keyMap.set('Edited', 'folder_edited')
      keyMap.set('Other', 'folder_other')
      keyMap.set('All Photos', 'folder_all_photos')

      const resKey: string | undefined = keyMap.get(groupKey)
      if (resKey !== undefined) {
        return resManager.getStringByNameSync(resKey)
      }
    } catch (e) {
      // Fallback to English key
    }
    return groupKey
  }

  // BUG-012: Determine a group name from a displayName and photoType.
  // Maps common filename prefixes to human-readable group names.
  private getGroupNameFromDisplayName(displayName: string, photoType: photoAccessHelper.PhotoType): string {
    const lowerName: string = displayName.toLowerCase()

    // Video files
    if (photoType === photoAccessHelper.PhotoType.VIDEO) {
      if (lowerName.startsWith('vid_') || lowerName.startsWith('video_')) {
        return 'Camera Videos'
      }
      if (lowerName.startsWith('screen_recording') || lowerName.startsWith('screenrecord')) {
        return 'Screen Recordings'
      }
      return 'Videos'
    }

    // Camera photos — common prefixes from various devices
    if (lowerName.startsWith('img_') || lowerName.startsWith('photo_') ||
        lowerName.startsWith('dsc_') || lowerName.startsWith('dscf') ||
        lowerName.startsWith('p_') || lowerName.startsWith('cam_')) {
      return 'Camera'
    }

    // Screenshots
    if (lowerName.startsWith('screenshot') || lowerName.startsWith('screen_shot') ||
        lowerName.startsWith('snap_') || lowerName.indexOf('screenshot') >= 0) {
      return 'Screenshots'
    }

    // Downloads / received files
    if (lowerName.startsWith('download') || lowerName.startsWith('received_')) {
      return 'Downloads'
    }

    // Edited images
    if (lowerName.startsWith('edit_') || lowerName.indexOf('_edit') >= 0) {
      return 'Edited'
    }

    // Default group for unrecognized patterns
    return 'Other'
  }

  // Build a Directory model from a photoAccessHelper Album.
  // Optimized: uses album.count and album.coverUri instead of iterating all assets.
  // Only samples first + last asset for date range and type info.
  private async buildDirectoryFromAlbum(
    album: photoAccessHelper.Album,
    index: number,
    filterMedia: number
  ): Promise<Directory | null> {
    // Use album's built-in count instead of fetching and iterating all assets
    const mediaCount: number = album.count
    if (mediaCount <= 0) {
      return null
    }

    const coverUri: string = album.coverUri || ''

    // Only fetch first + last asset for date range (not all assets)
    let latestModified: number = 0
    let latestTaken: number = 0
    let totalSize: number = 0
    let mediaTypes: number = TYPE_IMAGES  // default assumption

    const assetFetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: FETCH_COLUMNS,
      predicates: new dataSharePredicates.DataSharePredicates()
    }

    let assetResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null = null
    try {
      assetResult = await album.getAssets(assetFetchOptions)
      const assetCount: number = assetResult.getCount()

      if (assetCount > 0) {
        // Sample the first asset for dates, size, and type info
        const firstAsset: photoAccessHelper.PhotoAsset = await assetResult.getFirstObject()
        try {
          latestModified = toMilliseconds((firstAsset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number) || 0)
          latestTaken = toMilliseconds((firstAsset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN) as number) || 0)
          totalSize = (firstAsset.get(photoAccessHelper.PhotoKeys.SIZE) as number) || 0
        } catch (e) {
          // property access may fail
        }

        if (firstAsset.photoType === photoAccessHelper.PhotoType.VIDEO) {
          mediaTypes = TYPE_VIDEOS
        }

        // Check last asset too for latest dates (assets usually sorted by date desc)
        if (assetCount > 1) {
          const lastAsset: photoAccessHelper.PhotoAsset = await assetResult.getLastObject()
          try {
            const lastMod: number = toMilliseconds((lastAsset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number) || 0)
            const lastTak: number = toMilliseconds((lastAsset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN) as number) || 0)
            if (lastMod > latestModified) {
              latestModified = lastMod
            }
            if (lastTak > latestTaken) {
              latestTaken = lastTak
            }
          } catch (e) {
            // property access may fail
          }

          if (lastAsset.photoType === photoAccessHelper.PhotoType.VIDEO) {
            mediaTypes = mediaTypes | TYPE_VIDEOS
          } else {
            mediaTypes = mediaTypes | TYPE_IMAGES
          }
        }
      }
    } catch (err) {
      // Album asset fetch may fail
    } finally {
      if (assetResult !== null) {
        try {
          assetResult.close()
        } catch (e) {
          // Ignore close failure
        }
      }
    }

    // Check filter — skip if album's detected media types don't match the filter
    if (filterMedia !== 0 && (mediaTypes & filterMedia) === 0) {
      return null
    }

    const dir: Directory = new Directory(
      index,
      album.albumUri,
      coverUri,
      album.albumName,
      mediaCount,
      latestModified,
      latestTaken,
      totalSize,
      LOCATION_INTERNAL,
      mediaTypes,
      ''
    )
    return dir
  }

  // FR-002: Get media files from a specific folder path
  async getFilesFrom(
    path: string, filterMedia: number, sorting: number
  ): Promise<Array<Medium>> {
    this.resetStop()

    if (filterMedia === 0) {
      return []
    }

    let media: Array<Medium> = []

    if (path === FAVORITES) {
      media = await this.getFavoriteMedia(filterMedia)
    } else if (path === RECYCLE_BIN) {
      media = await this.getRecycleBinMedia(filterMedia)
    } else {
      media = await this.fetchMediaForPath(path, filterMedia)
    }

    return this.sortMedia(media, sorting)
  }

  // FR-020: Get all media assets (public entry point for search)
  async getAllMedia(filterMedia: number): Promise<Array<Medium>> {
    this.resetStop()
    return await this.fetchAllMedia(filterMedia)
  }

  // Fetch all media assets from the system using photoAccessHelper
  private async fetchAllMedia(filterMedia: number): Promise<Array<Medium>> {
    const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates()
    const media: Array<Medium> = []

    let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null = null
    try {
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: FETCH_COLUMNS,
        predicates: predicates
      }
      fetchResult = await this.photoHelper.getAssets(fetchOptions)
      const count: number = fetchResult.getCount()

      if (count <= 0) {
        return media
      }

      let asset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject()
      for (let i: number = 0; i < count; i++) {
        if (this.shouldStop) {
          break
        }

        const displayName: string = asset.displayName
        if (this.matchesFilter(asset.photoType, displayName, filterMedia)) {
          const medium: Medium = this.assetToMedium(asset)
          media.push(medium)
        }

        if (i < count - 1) {
          asset = await fetchResult.getNextObject()
        }
      }
    } catch (err) {
      const error: Error = err as Error
      console.error(`MediaScanner: fetchAllMedia failed: ${error.message}`)
    } finally {
      if (fetchResult !== null) {
        try {
          fetchResult.close()
        } catch (closeErr) {
          // Ignore close failure
        }
      }
    }

    return media
  }

  // Fetch media assets for a specific album URI or virtual group path
  // BUG-002 fix: path is now an album URI (from Albums API), not a filesystem path.
  // BUG-012 fix: Also handles __group__: virtual paths from displayName prefix fallback.
  private async fetchMediaForPath(
    path: string, filterMedia: number
  ): Promise<Array<Medium>> {
    // Handle "All Photos" virtual directory — return all assets
    if (path === '__all_photos__') {
      return await this.fetchAllMedia(filterMedia)
    }

    // BUG-012: Handle fallback group paths
    if (path.startsWith('__group__:')) {
      return await this.fetchMediaForGroup(path, filterMedia)
    }

    const media: Array<Medium> = []

    // Try to find the album matching this URI across both USER and SYSTEM album types
    const album: photoAccessHelper.Album | null = await this.findAlbumByUri(path)
    if (album === null) {
      return media
    }

    let assetResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null = null
    try {
      const assetFetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: FETCH_COLUMNS,
        predicates: new dataSharePredicates.DataSharePredicates()
      }
      assetResult = await album.getAssets(assetFetchOptions)
      const count: number = assetResult.getCount()

      if (count <= 0) {
        return media
      }

      let asset: photoAccessHelper.PhotoAsset = await assetResult.getFirstObject()
      for (let i: number = 0; i < count; i++) {
        if (this.shouldStop) {
          break
        }

        const displayName: string = asset.displayName
        if (this.matchesFilter(asset.photoType, displayName, filterMedia) &&
            this.shouldIncludeFile(displayName, true)) {
          const medium: Medium = this.assetToMedium(asset, path, album.albumName)
          media.push(medium)
        }

        if (i < count - 1) {
          asset = await assetResult.getNextObject()
        }
      }
    } catch (err) {
      const error: Error = err as Error
      console.error('MediaScanner: fetchMediaForPath failed: ' + error.message)
    } finally {
      if (assetResult !== null) {
        try {
          assetResult.close()
        } catch (closeErr) {
          // Ignore close failure
        }
      }
    }

    return media
  }

  // BUG-012: Fetch media belonging to a displayName prefix group
  private async fetchMediaForGroup(
    groupPath: string, filterMedia: number
  ): Promise<Array<Medium>> {
    const groupName: string = groupPath.substring('__group__:'.length)
    const media: Array<Medium> = []

    let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null = null
    try {
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: FETCH_COLUMNS,
        predicates: new dataSharePredicates.DataSharePredicates()
      }
      fetchResult = await this.photoHelper.getAssets(fetchOptions)
      const count: number = fetchResult.getCount()

      if (count <= 0) {
        return media
      }

      let asset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject()
      for (let i: number = 0; i < count; i++) {
        if (this.shouldStop) {
          break
        }

        const displayName: string = asset.displayName
        if (this.matchesFilter(asset.photoType, displayName, filterMedia) &&
            this.shouldIncludeFile(displayName, true)) {
          const assetGroup: string = this.getGroupNameFromDisplayName(displayName, asset.photoType)
          if (assetGroup === groupName) {
            const medium: Medium = this.assetToMedium(asset, groupPath, groupName)
            media.push(medium)
          }
        }

        if (i < count - 1) {
          asset = await fetchResult.getNextObject()
        }
      }
    } catch (err) {
      const error: Error = err as Error
      console.error(`MediaScanner: fetchMediaForGroup failed: ${error.message}`)
    } finally {
      if (fetchResult !== null) {
        try {
          fetchResult.close()
        } catch (closeErr) {
          // Ignore close failure
        }
      }
    }

    return media
  }

  // Find an album by its URI, searching across USER and SYSTEM album types
  private async findAlbumByUri(albumUri: string): Promise<photoAccessHelper.Album | null> {
    const albumFetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: [],
      predicates: new dataSharePredicates.DataSharePredicates()
    }

    // Search USER albums first (use ANY to match broader album set per BUG-012)
    let userAlbums: photoAccessHelper.FetchResult<photoAccessHelper.Album> | null = null
    let foundAlbum: photoAccessHelper.Album | null = null
    try {
      userAlbums = await this.photoHelper.getAlbums(
          photoAccessHelper.AlbumType.USER,
          photoAccessHelper.AlbumSubtype.ANY,
          albumFetchOptions
        )
      const userCount: number = userAlbums.getCount()
      if (userCount > 0) {
        let album: photoAccessHelper.Album = await userAlbums.getFirstObject()
        for (let i: number = 0; i < userCount; i++) {
          if (album.albumUri === albumUri) {
            foundAlbum = album
            break
          }
          if (i < userCount - 1) {
            album = await userAlbums.getNextObject()
          }
        }
      }
    } catch (e) {
      // USER albums may not be supported
    } finally {
      if (userAlbums !== null) {
        try { userAlbums.close() } catch (e) { /* ignore */ }
      }
    }
    if (foundAlbum !== null) {
      return foundAlbum
    }

    // Search SYSTEM albums using specific subtypes (ANY may not work for SYSTEM type)
    const sysSubtypes: Array<photoAccessHelper.AlbumSubtype> = [
      photoAccessHelper.AlbumSubtype.VIDEO,
      photoAccessHelper.AlbumSubtype.FAVORITE
    ]
    for (let st: number = 0; st < sysSubtypes.length; st++) {
      let sysAlbums: photoAccessHelper.FetchResult<photoAccessHelper.Album> | null = null
      let sysFoundAlbum: photoAccessHelper.Album | null = null
      try {
        sysAlbums = await this.photoHelper.getAlbums(
            photoAccessHelper.AlbumType.SYSTEM,
            sysSubtypes[st],
            albumFetchOptions
          )
        const sysCount: number = sysAlbums.getCount()
        if (sysCount > 0) {
          let album: photoAccessHelper.Album = await sysAlbums.getFirstObject()
          for (let i: number = 0; i < sysCount; i++) {
            if (album.albumUri === albumUri) {
              sysFoundAlbum = album
              break
            }
            if (i < sysCount - 1) {
              album = await sysAlbums.getNextObject()
            }
          }
        }
      } catch (e) {
        // This subtype may not be available
      } finally {
        if (sysAlbums !== null) {
          try { sysAlbums.close() } catch (e) { /* ignore */ }
        }
      }
      if (sysFoundAlbum !== null) {
        return sysFoundAlbum
      }
    }

    return null
  }

  // Fetch media marked as favorite
  // BUG-034: Get favorite media from internal FavoritesDao + photoAccessHelper
  // System FAVORITE flag may not be set (setFavorite API unavailable for third-party apps),
  // so we query our internal favorites table for URIs, then also query system favorites.
  private async getFavoriteMedia(filterMedia: number): Promise<Array<Medium>> {
    const media: Array<Medium> = []
    const addedPaths: Set<string> = new Set<string>()

    // Source 1: Internal FavoritesDao — our own favorite list
    try {
      const favDao: FavoritesDao = new FavoritesDao()
      const favPaths: Array<string> = await favDao.getValidatedPaths(this.context)
      for (let i: number = 0; i < favPaths.length; i++) {
        const uri: string = favPaths[i]
        if (addedPaths.has(uri)) {
          continue
        }
        try {
          const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates()
          predicates.equalTo(photoAccessHelper.PhotoKeys.URI, uri)
          const fetchOpt: photoAccessHelper.FetchOptions = {
            fetchColumns: FETCH_COLUMNS,
            predicates: predicates
          }
          const result: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await this.photoHelper.getAssets(fetchOpt)
          if (result.getCount() > 0) {
            const asset: photoAccessHelper.PhotoAsset = await result.getFirstObject()
            const displayName: string = asset.displayName
            if (this.matchesFilter(asset.photoType, displayName, filterMedia)) {
              const medium: Medium = this.assetToMedium(asset)
              medium.isFavorite = true
              media.push(medium)
              addedPaths.add(uri)
            }
          }
          result.close()
        } catch (assetErr) {
          // Asset may have been deleted — skip
        }
      }
    } catch (dbErr) {
      console.error('MediaScanner: getFavoriteMedia DB query failed: ' + (dbErr as Error).message)
    }

    // Source 2: System favorites (PhotoKeys.FAVORITE == true) — in case user favorited via system gallery
    let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null = null
    try {
      const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates()
      predicates.equalTo(photoAccessHelper.PhotoKeys.FAVORITE, true)

      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: FETCH_COLUMNS,
        predicates: predicates
      }
      fetchResult = await this.photoHelper.getAssets(fetchOptions)
      const count: number = fetchResult.getCount()

      if (count > 0) {
        let asset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject()
        for (let i: number = 0; i < count; i++) {
          if (this.shouldStop) {
            break
          }
          if (!addedPaths.has(asset.uri)) {
            const displayName: string = asset.displayName
            if (this.matchesFilter(asset.photoType, displayName, filterMedia)) {
              const medium: Medium = this.assetToMedium(asset)
              medium.isFavorite = true
              media.push(medium)
              addedPaths.add(asset.uri)
            }
          }
          if (i < count - 1) {
            asset = await fetchResult.getNextObject()
          }
        }
      }
    } catch (err) {
      const error: Error = err as Error
      console.error(`MediaScanner: getFavoriteMedia system query failed: ${error.message}`)
    } finally {
      if (fetchResult !== null) {
        try {
          fetchResult.close()
        } catch (closeErr) {
          // Ignore close failure
        }
      }
    }

    return media
  }

  // Fetch media in the recycle bin (trashed items)
  private async getRecycleBinMedia(filterMedia: number): Promise<Array<Medium>> {
    const media: Array<Medium> = []

    let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null = null
    try {
      const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates()
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: FETCH_COLUMNS,
        predicates: predicates
      }

      fetchResult = await this.photoHelper.getAssets(fetchOptions)
      const count: number = fetchResult.getCount()

      if (count <= 0) {
        return media
      }

      let asset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject()
      for (let i: number = 0; i < count; i++) {
        if (this.shouldStop) {
          break
        }

        const displayName: string = asset.displayName
        if (this.matchesFilter(asset.photoType, displayName, filterMedia)) {
          const medium: Medium = this.assetToMedium(asset)
          medium.deletedTS = medium.modified
          media.push(medium)
        }

        if (i < count - 1) {
          asset = await fetchResult.getNextObject()
        }
      }
    } catch (err) {
      const error: Error = err as Error
      console.error(`MediaScanner: getRecycleBinMedia failed: ${error.message}`)
    } finally {
      if (fetchResult !== null) {
        try {
          fetchResult.close()
        } catch (closeErr) {
          // Ignore close failure
        }
      }
    }

    return media
  }

  // FR-003: Check if asset matches filter bitmask
  private matchesFilter(
    photoType: photoAccessHelper.PhotoType,
    displayName: string,
    filterMedia: number
  ): boolean {
    const lowerName: string = displayName.toLowerCase()

    if (photoType === photoAccessHelper.PhotoType.VIDEO) {
      return (filterMedia & TYPE_VIDEOS) !== 0
    }

    // Image subtypes - check extensions for GIF, SVG, RAW
    if (lowerName.endsWith('.gif')) {
      return (filterMedia & TYPE_GIFS) !== 0
    }

    if (lowerName.endsWith('.svg')) {
      return (filterMedia & TYPE_SVGS) !== 0
    }

    if (this.isRawExtension(lowerName)) {
      return (filterMedia & TYPE_RAWS) !== 0
    }

    // Default: regular image
    return (filterMedia & TYPE_IMAGES) !== 0
  }

  // Check if the filename has a RAW image extension
  private isRawExtension(lowerName: string): boolean {
    for (let i: number = 0; i < RAW_EXTENSIONS.length; i++) {
      if (lowerName.endsWith(RAW_EXTENSIONS[i])) {
        return true
      }
    }
    return false
  }

  // FR-004: Sort media array
  private sortMedia(media: Array<Medium>, sorting: number): Array<Medium> {
    if ((sorting & SORT_BY_RANDOM) !== 0) {
      return this.shuffleArray(media)
    }

    const ascending: boolean = (sorting & SORT_DESCENDING) === 0
    const sortFlag: number = sorting & ~SORT_DESCENDING

    media.sort((a: Medium, b: Medium): number => {
      let result: number = 0
      if ((sortFlag & SORT_BY_NAME) !== 0) {
        result = a.name.localeCompare(b.name, undefined, { numeric: true })
      } else if ((sortFlag & SORT_BY_DATE_MODIFIED) !== 0) {
        result = a.modified - b.modified
      } else if ((sortFlag & SORT_BY_SIZE) !== 0) {
        result = a.size - b.size
      } else if ((sortFlag & SORT_BY_DATE_TAKEN) !== 0) {
        result = a.taken - b.taken
      } else if ((sortFlag & SORT_BY_PATH) !== 0) {
        result = a.path.localeCompare(b.path)
      }
      return ascending ? result : -result
    })
    return media
  }

  // FR-006: Hidden file check
  private shouldIncludeFile(name: string, showHidden: boolean): boolean {
    if (name.startsWith('.') && !showHidden) {
      return false
    }
    return true
  }

  // Map photoAccessHelper asset to Medium
  // BUG-002 fix: parentPath is now the album URI, not extracted from the asset URI.
  // When albumUri is provided (from album-based queries), it is used as parentPath.
  // When not provided (e.g., from fetchAllMedia), we fall back to empty string since
  // the asset URI (file://media/Photo/xxx) does not contain real folder information.
  private assetToMedium(
    asset: photoAccessHelper.PhotoAsset,
    albumUri: string = '',
    albumName: string = ''
  ): Medium {
    const uri: string = asset.uri
    const displayName: string = asset.displayName

    // Use album URI as parent path instead of parsing the opaque asset URI
    const parentPath: string = albumUri

    let modified: number = 0
    let taken: number = 0
    let size: number = 0
    try {
      modified = toMilliseconds((asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number) || 0)
      taken = toMilliseconds((asset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN) as number) || 0)
      size = (asset.get(photoAccessHelper.PhotoKeys.SIZE) as number) || 0
    } catch (e) {
      // Fallback to defaults on property access failure
    }

    // Determine type
    let mediaType: number = TYPE_IMAGES
    let videoDuration: number = 0

    if (asset.photoType === photoAccessHelper.PhotoType.VIDEO) {
      mediaType = TYPE_VIDEOS
      try {
        videoDuration = (asset.get(photoAccessHelper.PhotoKeys.DURATION) as number) || 0
      } catch (e) {
        // Fallback to 0 on property access failure
      }
    } else {
      const lowerName: string = displayName.toLowerCase()
      if (lowerName.endsWith('.gif')) {
        mediaType = TYPE_GIFS
      } else if (lowerName.endsWith('.svg')) {
        mediaType = TYPE_SVGS
      } else if (this.isRawExtension(lowerName)) {
        mediaType = TYPE_RAWS
      } else {
        mediaType = TYPE_IMAGES
      }
    }

    // BUG-034: Read favorite from both system (photoAccessHelper) and internal DB (FavoritesDao)
    let isFav: boolean = false
    try {
      isFav = (asset.get(photoAccessHelper.PhotoKeys.FAVORITE) as boolean) || false
    } catch (e) {
      // Favorite property not available — check internal DB below
    }
    // Also check internal favorites table (our toggleFavorite writes here)
    if (!isFav && this.favoritePaths.has(uri)) {
      isFav = true
    }

    const medium: Medium = new Medium(
      0,             // id: HarmonyOS uses URI, not numeric ID
      displayName,   // name
      uri,           // path
      parentPath,    // parentPath
      modified,      // modified
      taken,         // taken
      size,          // size
      mediaType,     // type
      videoDuration, // videoDuration
      isFav,         // isFavorite — from system
      0,             // deletedTS
      0              // mediaStoreId
    )

    return medium
  }

  // Sort directories
  private sortDirectories(dirs: Array<Directory>, sorting: number): Array<Directory> {
    const ascending: boolean = (sorting & SORT_DESCENDING) === 0
    const sortFlag: number = sorting & ~SORT_DESCENDING

    dirs.sort((a: Directory, b: Directory): number => {
      let result: number = 0
      if ((sortFlag & SORT_BY_NAME) !== 0) {
        result = a.name.localeCompare(b.name, undefined, { numeric: true })
      } else if ((sortFlag & SORT_BY_DATE_MODIFIED) !== 0) {
        result = a.modified - b.modified
      } else if ((sortFlag & SORT_BY_SIZE) !== 0) {
        result = a.size - b.size
      } else if ((sortFlag & SORT_BY_DATE_TAKEN) !== 0) {
        result = a.taken - b.taken
      } else if ((sortFlag & SORT_BY_PATH) !== 0) {
        result = a.path.localeCompare(b.path)
      }
      return ascending ? result : -result
    })
    return dirs
  }

  // Extract directory name from a path string
  private extractDirectoryName(path: string): string {
    if (path.length === 0) {
      return ''
    }
    const lastSlash: number = path.lastIndexOf('/')
    if (lastSlash >= 0 && lastSlash < path.length - 1) {
      return path.substring(lastSlash + 1)
    }
    return path
  }

  // Fisher-Yates shuffle for random sort
  private shuffleArray(arr: Array<Medium>): Array<Medium> {
    for (let i: number = arr.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1))
      const temp: Medium = arr[i]
      arr[i] = arr[j]
      arr[j] = temp
    }
    return arr
  }

  // PAT-015: Stop scan with mutex guard
  stopScan(): void {
    this.scanMutex = true
    this.shouldStop = true
    this.scanMutex = false
  }

  // PAT-015: Reset stop flag with mutex guard
  resetStop(): void {
    this.scanMutex = true
    this.shouldStop = false
    this.scanMutex = false
  }

  // Check if scan has been interrupted
  isStopped(): boolean {
    return this.shouldStop
  }

  // FR-007: Filter directories by exclude/include lists and hidden visibility
  filterDirectories(
    dirs: Directory[],
    excludedPaths: Set<string>,
    includedPaths: Set<string>,
    showHidden: boolean
  ): Directory[] {
    const excludedArr: Array<string> = Array.from<string>(excludedPaths)
    const includedArr: Array<string> = Array.from<string>(includedPaths)
    const result: Directory[] = []
    for (let i: number = 0; i < dirs.length; i++) {
      const dir: Directory = dirs[i]
      if (shouldFolderBeVisible(dir.path, excludedArr, includedArr, showHidden)) {
        result.push(dir)
      }
    }
    return result
  }

  // BUG-034e: Single data source — count comes from getFavoriteMedia(), not separate path query.
  // This ensures folder count always matches the actual displayable content.
  async getFavoritesFolder(): Promise<Directory | null> {
    const defaultFilter: number = TYPE_IMAGES | TYPE_VIDEOS | TYPE_GIFS | TYPE_RAWS | TYPE_SVGS
    const favMedia: Array<Medium> = await this.getFavoriteMedia(defaultFilter)
    if (favMedia.length === 0) {
      return null
    }

    const thumbnail: string = favMedia[0].path
    let combinedTypes: number = 0
    for (let i: number = 0; i < favMedia.length; i++) {
      combinedTypes = combinedTypes | favMedia[i].type
    }

    const dir: Directory = new Directory(
      0,
      FAVORITES,
      thumbnail,
      FAVORITES,
      favMedia.length,
      0,
      0,
      0,
      LOCATION_INTERNAL,
      combinedTypes,
      ''
    )
    return dir
  }

  // FR-009: Build Recycle Bin virtual folder from MediumDao (deletedTS > 0)
  // BUG-041e: Always return recycle bin folder when enabled (even if empty)
  // Internal MediumDao has no records for photoAccessHelper media, so we create a placeholder.
  async getRecycleBinFolder(): Promise<Directory | null> {
    const mediumDao: MediumDao = MediumDao.getInstance()
    const deletedMedia: Array<Medium> = await mediumDao.getDeletedMedia()
    if (deletedMedia.length === 0) {
      // Return empty recycle bin placeholder (so user can see the entry)
      return new Directory(0, RECYCLE_BIN, '', '回收站', 0, 0, 0, 0, LOCATION_INTERNAL, 0, '')
    }

    let totalSize: number = 0
    let latestModified: number = 0
    let latestTaken: number = 0
    let combinedTypes: number = 0
    let thumbnail: string = ''

    for (let i: number = 0; i < deletedMedia.length; i++) {
      const m: Medium = deletedMedia[i]
      totalSize = totalSize + m.size
      if (m.modified > latestModified) {
        latestModified = m.modified
      }
      if (m.taken > latestTaken) {
        latestTaken = m.taken
      }
      combinedTypes = combinedTypes | m.type
      if (i === 0) {
        thumbnail = m.path
      }
    }

    const dir: Directory = new Directory(
      0,
      RECYCLE_BIN,
      thumbnail,
      RECYCLE_BIN,
      deletedMedia.length,
      latestModified,
      latestTaken,
      totalSize,
      LOCATION_INTERNAL,
      combinedTypes,
      ''
    )
    return dir
  }

  // FR-009: Clean recycle bin items older than maxAgeMs milliseconds
  async cleanRecycleBin(maxAgeMs: number): Promise<number> {
    const mediumDao: MediumDao = MediumDao.getInstance()
    const cutoff: number = Date.now() - maxAgeMs
    const oldItems: Array<Medium> = await mediumDao.getOldRecycleBinItems(cutoff)
    if (oldItems.length === 0) {
      return 0
    }

    for (let i: number = 0; i < oldItems.length; i++) {
      await mediumDao.deleteMediumPath(oldItems[i].path)
    }

    return oldItems.length
  }

  // FR-010: Batch date-taken retrieval — returns map of path -> dateTaken
  async getDateTakensMap(): Promise<Map<string, number>> {
    const allMedia: Array<Medium> = await this.fetchAllMedia(TYPE_IMAGES | TYPE_VIDEOS | TYPE_GIFS | TYPE_RAWS | TYPE_SVGS)
    const map: Map<string, number> = new Map<string, number>()
    for (let i: number = 0; i < allMedia.length; i++) {
      const m: Medium = allMedia[i]
      map.set(m.path, m.taken)
    }
    return map
  }

  // FR-011: Batch date-modified retrieval — returns map of path -> dateModified
  async getDateModifiedsMap(): Promise<Map<string, number>> {
    const allMedia: Array<Medium> = await this.fetchAllMedia(TYPE_IMAGES | TYPE_VIDEOS | TYPE_GIFS | TYPE_RAWS | TYPE_SVGS)
    const map: Map<string, number> = new Map<string, number>()
    for (let i: number = 0; i < allMedia.length; i++) {
      const m: Medium = allMedia[i]
      map.set(m.path, m.modified)
    }
    return map
  }
}

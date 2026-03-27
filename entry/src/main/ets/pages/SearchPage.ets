// =============================================================================
// SearchPage.ets — Media search page
// BA-002 (BlueAgent): Rewritten from client-side filter to server-side search
// using DataSharePredicates.contains(DISPLAY_NAME, query)
// =============================================================================

import { router } from '@kit.ArkUI'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { dataSharePredicates } from '@kit.ArkData'
import { Medium } from '../common/models/Medium'
import { ConfigManager } from '../datastore/ConfigManager'
import { MediaItem } from '../components/MediaItem'
import { TYPE_IMAGES, TYPE_VIDEOS, TYPE_GIFS, TYPE_RAWS, TYPE_SVGS } from '../common/constants/Constants'

interface ViewingPageParams {
  mediaListJson: string
  selectedIndex: number
  folderPath: string
}

// Columns to fetch for search results
const SEARCH_COLUMNS: Array<string> = [
  photoAccessHelper.PhotoKeys.URI,
  photoAccessHelper.PhotoKeys.PHOTO_TYPE,
  photoAccessHelper.PhotoKeys.DISPLAY_NAME,
  photoAccessHelper.PhotoKeys.DATE_MODIFIED,
  photoAccessHelper.PhotoKeys.SIZE,
  photoAccessHelper.PhotoKeys.DURATION
]

@Entry
@Component
struct SearchPage {
  @State searchQuery: string = ''
  @State results: Medium[] = []
  @State isLoading: boolean = false
  @State hasSearched: boolean = false
  @State columnCount: number = 3
  @State displayFileNames: boolean = false

  private debounceTimerId: number = -1
  private helper: photoAccessHelper.PhotoAccessHelper | null = null

  aboutToAppear(): void {
    const config: ConfigManager = ConfigManager.getInstance()
    this.columnCount = config.mediaColumnCnt
    this.displayFileNames = config.displayFileNames
    try {
      this.helper = photoAccessHelper.getPhotoAccessHelper(getContext(this))
    } catch (e) {
      console.error('[SearchPage] Failed to get PhotoAccessHelper')
    }
  }

  onBackPress(): boolean {
    router.back()
    return true
  }

  // Client-side search: DataSharePredicates only has equalTo, no contains/like.
  // Load all assets once, then filter by displayName in memory.
  private allMedia: Medium[] = []
  private allMediaLoaded: boolean = false

  private async ensureAllMediaLoaded(): Promise<void> {
    if (this.allMediaLoaded || this.helper === null) {
      return
    }
    this.isLoading = true
    try {
      const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates()
      const fetchOpt: photoAccessHelper.FetchOptions = {
        fetchColumns: SEARCH_COLUMNS,
        predicates: predicates
      }
      const fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
        await this.helper.getAssets(fetchOpt)
      const count: number = fetchResult.getCount()
      console.info('[SearchPage] loaded all media: ' + count.toString())

      if (count > 0) {
        let asset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject()
        for (let i: number = 0; i < count; i++) {
          this.allMedia.push(this.assetToMedium(asset))
          if (i < count - 1) {
            asset = await fetchResult.getNextObject()
          }
        }
      }
      fetchResult.close()
      this.allMediaLoaded = true
    } catch (e) {
      console.error('[SearchPage] ensureAllMediaLoaded failed: ' + (e as Error).message)
    }
    this.isLoading = false
  }

  private async searchMedia(query: string): Promise<void> {
    if (query.length === 0) {
      this.results = []
      this.hasSearched = false
      return
    }

    await this.ensureAllMediaLoaded()
    this.hasSearched = true

    const lower: string = query.toLowerCase()
    const filtered: Medium[] = []
    for (let i: number = 0; i < this.allMedia.length; i++) {
      const m: Medium = this.allMedia[i]
      if (m.name.toLowerCase().includes(lower)) {
        filtered.push(m)
      }
    }
    // Prefix matches first
    filtered.sort((a: Medium, b: Medium): number => {
      const aStarts: number = a.name.toLowerCase().startsWith(lower) ? 0 : 1
      const bStarts: number = b.name.toLowerCase().startsWith(lower) ? 0 : 1
      return aStarts - bStarts
    })
    this.results = filtered
    console.info('[SearchPage] query="' + query + '" results=' + filtered.length.toString())
  }

  private assetToMedium(asset: photoAccessHelper.PhotoAsset): Medium {
    const uri: string = asset.uri
    const displayName: string = asset.displayName

    let modified: number = 0
    let size: number = 0
    try {
      const modRaw: number = (asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number) || 0
      modified = modRaw > 0 && modRaw < 20000000000 ? modRaw * 1000 : modRaw
      size = (asset.get(photoAccessHelper.PhotoKeys.SIZE) as number) || 0
    } catch (e) {
      // Fallback
    }

    let mediaType: number = TYPE_IMAGES
    let videoDuration: number = 0
    if (asset.photoType === photoAccessHelper.PhotoType.VIDEO) {
      mediaType = TYPE_VIDEOS
      try {
        videoDuration = (asset.get(photoAccessHelper.PhotoKeys.DURATION) as number) || 0
      } catch (e) {
        // Fallback
      }
    } else {
      const lower: string = displayName.toLowerCase()
      if (lower.endsWith('.gif')) {
        mediaType = TYPE_GIFS
      } else if (lower.endsWith('.svg')) {
        mediaType = TYPE_SVGS
      } else if (lower.endsWith('.raw') || lower.endsWith('.dng') || lower.endsWith('.cr2') || lower.endsWith('.nef')) {
        mediaType = TYPE_RAWS
      }
    }

    return new Medium(0, displayName, uri, '', modified, 0, size, mediaType, videoDuration, false, 0, 0)
  }

  private debouncedSearch(query: string): void {
    if (this.debounceTimerId !== -1) {
      clearTimeout(this.debounceTimerId)
    }
    this.debounceTimerId = setTimeout((): void => {
      this.searchMedia(query)
      this.debounceTimerId = -1
    }, 300)
  }

  private navigateToViewing(index: number): void {
    const serialized: Object[] = []
    for (let i: number = 0; i < this.results.length; i++) {
      const m: Medium = this.results[i]
      const obj: Record<string, Object> = {} as Record<string, Object>
      obj['id'] = m.id
      obj['name'] = m.name
      obj['path'] = m.path
      obj['parentPath'] = m.parentPath
      obj['modified'] = m.modified
      obj['taken'] = m.taken
      obj['size'] = m.size
      obj['type'] = m.type
      obj['videoDuration'] = m.videoDuration
      obj['isFavorite'] = m.isFavorite
      obj['deletedTS'] = m.deletedTS
      obj['mediaStoreId'] = m.mediaStoreId
      serialized.push(obj)
    }

    try {
      const navParams: ViewingPageParams = {
        mediaListJson: JSON.stringify(serialized),
        selectedIndex: index,
        folderPath: ''
      }
      router.pushUrl({ url: 'pages/ViewingPage', params: navParams })
    } catch (e) {
      console.error('[SearchPage] Navigation failed')
    }
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24)
          .height(24)
          .onClick((): void => {
            router.back()
          })
        Text($r('app.string.search'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 16 })
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // Search input
      Search({ value: this.searchQuery, placeholder: $r('app.string.search_files') })
        .width('100%')
        .padding({ left: 16, right: 16 })
        .onChange((value: string): void => {
          this.searchQuery = value
          this.debouncedSearch(value)
        })
        .onSubmit((value: string): void => {
          if (this.debounceTimerId !== -1) {
            clearTimeout(this.debounceTimerId)
            this.debounceTimerId = -1
          }
          this.searchMedia(value)
        })

      // Content
      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .margin({ top: 100 })
      } else if (this.hasSearched && this.results.length === 0) {
        Column() {
          Text($r('app.string.no_items_found'))
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 100 })
        }
        .width('100%')
        .layoutWeight(1)
      } else if (!this.hasSearched) {
        Column() {
          Text($r('app.string.search_files'))
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 100 })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Grid() {
          ForEach(this.results, (item: Medium, index: number) => {
            GridItem() {
              MediaItem({
                medium: item,
                showFileName: true
              })
                .onClick((): void => {
                  this.navigateToViewing(index)
                })
            }
          }, (item: Medium, _index: number): string => {
            return item.path
          })
        }
        .columnsTemplate(this.buildColumnsTemplate())
        .columnsGap(2)
        .rowsGap(2)
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  buildColumnsTemplate(): string {
    let template: string = ''
    for (let i: number = 0; i < this.columnCount; i++) {
      if (i > 0) {
        template += ' '
      }
      template += '1fr'
    }
    return template
  }
}

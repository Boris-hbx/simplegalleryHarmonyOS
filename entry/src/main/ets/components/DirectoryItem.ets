import { Directory } from '../common/models/Directory'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { dataSharePredicates } from '@kit.ArkData'
import { image } from '@kit.ImageKit'

// Video file extensions for fast type detection (FR-C03)
const VIDEO_EXTENSIONS: Array<string> = ['.mp4', '.mkv', '.avi', '.3gp', '.mov', '.webm', '.ts', '.flv', '.wmv', '.m4v']

@Component
export struct DirectoryItem {
  directory: Directory = new Directory()
  isListMode: boolean = false
  // BUG-R6B-8: Must be @Prop so ArkUI updates child when parent @State changes.
  // Plain properties don't trigger re-render — blue checkmarks were invisible.
  @Prop isSelected: boolean = false
  @Prop isMultiSelectMode: boolean = false
  @State thumbnailFailed: boolean = false
  // T-067: Video thumbnail PixelMap for folder covers that are video URIs
  @State private videoThumbnail: image.PixelMap | undefined = undefined
  private lastTmbUri: string = ''

  aboutToAppear(): void {
    this.loadVideoThumbnailIfNeeded()
  }

  // T-067: Release PixelMap native resource when component is recycled by LazyForEach
  // to prevent OOM when scrolling through many video folders.
  aboutToDisappear(): void {
    if (this.videoThumbnail !== undefined) {
      try {
        this.videoThumbnail.release()
      } catch (e) {
        // Ignore release failure
      }
      this.videoThumbnail = undefined
      this.lastTmbUri = ''
    }
  }

  // T-067 (FR-C01/C03): Check if the cover URI points to a video file by extension
  private isVideoUri(uri: string): boolean {
    if (uri.length === 0) {
      return false
    }
    const lowerUri: string = uri.toLowerCase()
    for (let i: number = 0; i < VIDEO_EXTENSIONS.length; i++) {
      if (lowerUri.endsWith(VIDEO_EXTENSIONS[i])) {
        return true
      }
    }
    return false
  }

  // T-067 (FR-C01/C04): Load video thumbnail via PhotoAsset.getThumbnail() for video cover URIs.
  // Image(videoUri) cannot auto-extract video first frame from photoAccessHelper URIs (PIT-053).
  private loadVideoThumbnailIfNeeded(): void {
    const tmb: string = this.directory.tmb
    // Only load if the directory cover is a video URI or if it's a video-only folder
    // whose cover URI failed to render as an image
    if (!this.isVideoUri(tmb) && !this.directory.isVideoOnly()) {
      return
    }
    // Skip if we already loaded for this URI
    if (this.lastTmbUri === tmb && this.videoThumbnail !== undefined) {
      return
    }
    this.lastTmbUri = tmb
    this.videoThumbnail = undefined

    if (tmb.length === 0) {
      return
    }

    try {
      const context: Context = getContext(this)
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
      const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates()
      predicates.equalTo(photoAccessHelper.PhotoKeys.URI, tmb)
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [photoAccessHelper.PhotoKeys.URI],
        predicates: predicates
      }
      helper.getAssets(fetchOptions).then((fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset>): void => {
        if (fetchResult.getCount() > 0) {
          fetchResult.getFirstObject().then((asset: photoAccessHelper.PhotoAsset): void => {
            asset.getThumbnail({ width: 256, height: 256 }).then((pixelMap: image.PixelMap): void => {
              this.videoThumbnail = pixelMap
              this.thumbnailFailed = false
            }).catch((): void => {
              console.error('[DirectoryItem] getThumbnail failed for ' + tmb)
            })
            fetchResult.close()
          }).catch((): void => {
            fetchResult.close()
          })
        } else {
          fetchResult.close()
        }
      }).catch((): void => {
        console.error('[DirectoryItem] getAssets failed for video thumbnail')
      })
    } catch (e) {
      console.error('[DirectoryItem] loadVideoThumbnailIfNeeded error')
    }
  }

  build() {
    if (this.isListMode) {
      this.buildListItem()
    } else {
      this.buildGridItem()
    }
  }

  @Builder
  buildListItem() {
    Row() {
      // Selection checkmark in multi-select mode — only shown on selected items
      if (this.isMultiSelectMode && this.isSelected) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(24).height(24)
            .fill('#007DFF')
          Image($r('sys.media.ohos_ic_public_ok'))
            .width(14).height(14)
            .fillColor(Color.White)
        }
        .margin({ right: 12 })
      }

      // BUG-016 + T-067: Show thumbnail — use video PixelMap for video covers (FR-C01)
      // FR-C02: No play icon overlay on folder view thumbnails
      // BUG-R6B-3: Removed .alt('') — it may cause app icon overlay on video thumbnails.
      // Added dark background so partial failures show dark, not app icon.
      if (this.videoThumbnail !== undefined) {
        // T-067: Video cover rendered from getThumbnail() PixelMap
        Image(this.videoThumbnail)
          .width(56)
          .height(56)
          .borderRadius(4)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#333333')
          .draggable(false)
      } else if (this.directory.tmb.length > 0 && !this.thumbnailFailed) {
        // BUG-032: Wrap Image in Stack to prevent app icon showing through
        Stack() {
          Column()
            .width(56)
            .height(56)
            .borderRadius(4)
            .backgroundColor('#333333')
          Image(this.directory.tmb)
            .width(56)
            .height(56)
            .borderRadius(4)
            .objectFit(ImageFit.Cover)
            .draggable(false)
            .onError(() => {
              this.thumbnailFailed = true
              this.loadVideoThumbnailIfNeeded()
            })
        }
        .width(56)
        .height(56)
        .clip(true)
        .borderRadius(4)
      } else {
        // Placeholder — dark background with folder icon
        Column() {
          Text('📁')
            .fontSize(28)
        }
        .width(56)
        .height(56)
        .borderRadius(4)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#333333')
      }

      Column() {
        Text(this.directory.name)
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.directory.mediaCnt.toString() + ' items')
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.isSelected
      ? $r('sys.color.ohos_id_color_activated_transparent')
      : $r('sys.color.ohos_id_color_background'))
  }

  @Builder
  buildGridItem() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Thumbnail fills entire square (matches Android dir_thumbnail: match_parent)
      // T-067 (FR-C01): Video cover uses getThumbnail() PixelMap
      // FR-C02: No play icon overlay on folder view thumbnails
      // BUG-R6B-3: Removed .alt('') — may cause app icon overlay. Added dark background.
      if (this.videoThumbnail !== undefined) {
        // T-067: Video cover rendered from getThumbnail() PixelMap
        Image(this.videoThumbnail)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .backgroundColor('#333333')
          .draggable(false)
      } else if (this.directory.tmb.length > 0 && !this.thumbnailFailed) {
        // BUG-032: Wrap Image in Stack with dark background to prevent
        // app icon from showing through while Image loads or fails silently
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#333333')
          Image(this.directory.tmb)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .draggable(false)
            .onError(() => {
              this.thumbnailFailed = true
              // T-067: If Image(uri) fails, try video thumbnail loading as fallback
              this.loadVideoThumbnailIfNeeded()
            })
        }
        .width('100%')
        .height('100%')
      } else {
        // Placeholder — dark background with folder icon
        Column() {
          Text('📁')
            .fontSize(40)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#333333')
      }

      // Bottom gradient overlay + text (matches Android gradient_background + dir_bottom_holder)
      Column() {
        Text(this.directory.name)
          .fontSize(14)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.directory.mediaCnt.toString())
          .fontSize(12)
          .fontColor('#CCFFFFFF')
          .width('100%')
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4, bottom: 6 })
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [['#00000000', 0.0], ['#80000000', 1.0]]
      })

      // Highlight overlay when selected — semi-transparent blue tint
      if (this.isSelected) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 125, 255, 0.25)')
      }

      // Selection checkmark overlay at top-right — only shown on selected items (Android behavior)
      // Unselected items show NO indicator (unlike system gallery that shows gray circles on all)
      // Round6-Fix8: Moved AFTER highlight overlay so checkmark is not obscured
      if (this.isMultiSelectMode && this.isSelected) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(24).height(24)
            .fill('#007DFF')
          Image($r('sys.media.ohos_ic_public_ok'))
            .width(14).height(14)
            .fillColor(Color.White)
        }
        .position({ right: 6, top: 6 })
      }
    }
    .width('100%')
    .aspectRatio(1)
    .clip(true)
    .backgroundColor('#F0F0F0')
  }
}

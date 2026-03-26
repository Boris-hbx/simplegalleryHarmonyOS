import { Medium } from '../common/models/Medium'
import { TYPE_VIDEOS } from '../common/constants/Constants'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { dataSharePredicates } from '@kit.ArkData'
import { image } from '@kit.ImageKit'

@Component
export struct MediaItem {
  @Prop medium: Medium
  @Prop showFileName: boolean = false
  @Prop isListMode: boolean = false
  @Prop isSelected: boolean = false
  @Prop isMultiSelectMode: boolean = false
  // BUG-021: Video thumbnail PixelMap loaded via photoAccessHelper.getThumbnail()
  @State private videoThumbnail: image.PixelMap | undefined = undefined
  private lastThumbnailPath: string = ''

  aboutToAppear(): void {
    this.loadVideoThumbnail()
  }

  // BUG-021: Load video thumbnail asynchronously using PhotoAsset.getThumbnail()
  // Image(uri) works for images but not videos with photoAccessHelper URIs.
  private loadVideoThumbnail(): void {
    if (this.medium.type !== TYPE_VIDEOS) {
      return
    }
    if (this.lastThumbnailPath === this.medium.path) {
      return
    }
    this.lastThumbnailPath = this.medium.path
    this.videoThumbnail = undefined

    try {
      const context: Context = getContext(this)
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
      const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates()
      predicates.equalTo(photoAccessHelper.PhotoKeys.URI, this.medium.path)
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [photoAccessHelper.PhotoKeys.URI],
        predicates: predicates
      }
      helper.getAssets(fetchOptions).then((fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset>): void => {
        if (fetchResult.getCount() > 0) {
          fetchResult.getFirstObject().then((asset: photoAccessHelper.PhotoAsset): void => {
            asset.getThumbnail({ width: 256, height: 256 }).then((pixelMap: image.PixelMap): void => {
              this.videoThumbnail = pixelMap
            }).catch((): void => {
              console.error('[MediaItem] getThumbnail failed for ' + this.medium.path)
            })
            fetchResult.close()
          }).catch((): void => {
            fetchResult.close()
          })
        } else {
          fetchResult.close()
        }
      }).catch((): void => {
        console.error('[MediaItem] getAssets failed for video thumbnail')
      })
    } catch (e) {
      console.error('[MediaItem] loadVideoThumbnail error')
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
  buildGridItem() {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        // BUG-017 + BUG-021: Video thumbnail with play icon overlay.
        // Video URIs (file://media/Photo/xxx) don't render via Image(uri) for videos.
        // Use getThumbnail() PixelMap loaded in aboutToAppear().
        if (this.medium.type === TYPE_VIDEOS) {
          Stack() {
            // Solid background ensures visibility while thumbnail loads
            Column()
              .width('100%')
              .aspectRatio(1)
              .borderRadius(2)
              .backgroundColor('#333333')
            // BUG-021 fix: Use PixelMap from getThumbnail() instead of raw URI
            if (this.videoThumbnail !== undefined) {
              Image(this.videoThumbnail)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Cover)
                .borderRadius(2)
            }
            Image($r('sys.media.ohos_ic_public_play'))
              .width(36)
              .height(36)
              .fillColor('#FFFFFF')
          }
          .width('100%')
          .aspectRatio(1)
        } else {
          Image(this.medium.path)
            .width('100%')
            .aspectRatio(1)
            .objectFit(ImageFit.Cover)
            .borderRadius(2)
        }

        // Overlay row for type label and duration
        if (this.medium.isVideo() || this.medium.isGIF() || this.medium.isRaw() || this.medium.isSVG()) {
          Row() {
            if (this.medium.isVideo()) {
              Text(this.formatDuration(this.medium.videoDuration))
                .fontSize(11)
                .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
                .borderRadius(2)
            } else if (this.medium.isGIF()) {
              Text('GIF')
                .fontSize(11)
                .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
                .fontWeight(FontWeight.Bold)
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
                .borderRadius(2)
            } else if (this.medium.isRaw()) {
              Text('RAW')
                .fontSize(11)
                .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
                .fontWeight(FontWeight.Bold)
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
                .borderRadius(2)
            } else if (this.medium.isSVG()) {
              Text('SVG')
                .fontSize(11)
                .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
                .fontWeight(FontWeight.Bold)
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
                .borderRadius(2)
            }
          }
          .width('100%')
          .padding({ left: 4, bottom: 4 })
        }

        // Favorite star overlay at top-right
        if (this.medium.isFavorite && !this.isMultiSelectMode) {
          Image($r('app.media.ic_favor_filled'))
            .width(16)
            .height(16)
            .position({ x: '100%', y: 0 })
            .markAnchor({ x: 20, y: -4 })
        }

        // Selection checkbox overlay in multi-select mode
        if (this.isMultiSelectMode) {
          Image(this.isSelected
            ? $r('app.media.ic_check_filled')
            : $r('app.media.ic_check'))
            .width(24)
            .height(24)
            .fillColor(this.isSelected
              ? $r('sys.color.ohos_id_color_activated')
              : $r('sys.color.ohos_id_color_text_primary_contrary'))
            .position({ x: '100%', y: 4 })
            .markAnchor({ x: 28, y: 0 })
        }

        // Highlight overlay when selected
        if (this.isSelected) {
          Column()
            .width('100%')
            .aspectRatio(1)
            .borderRadius(2)
            .backgroundColor($r('sys.color.ohos_id_color_activated_transparent'))
        }
      }
      .width('100%')

      // Optional filename below thumbnail
      if (this.showFileName) {
        Text(this.medium.name)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 4 })
      }
    }
    .width('100%')
  }

  @Builder
  buildListItem() {
    Row() {
      // Checkbox area in multi-select mode
      if (this.isMultiSelectMode) {
        Image(this.isSelected
          ? $r('app.media.ic_check_filled')
          : $r('app.media.ic_check'))
          .width(24)
          .height(24)
          .fillColor(this.isSelected
            ? $r('sys.color.ohos_id_color_activated')
            : $r('sys.color.ohos_id_color_text_secondary'))
          .margin({ right: 12 })
      }

      // BUG-017 + BUG-021: Thumbnail on the left with video placeholder
      if (this.medium.type === TYPE_VIDEOS) {
        Stack() {
          Column()
            .width(56)
            .height(56)
            .borderRadius(4)
            .backgroundColor('#333333')
          // BUG-021 fix: Use PixelMap from getThumbnail() instead of raw URI
          if (this.videoThumbnail !== undefined) {
            Image(this.videoThumbnail)
              .width(56)
              .height(56)
              .objectFit(ImageFit.Cover)
              .borderRadius(4)
          }
          Image($r('sys.media.ohos_ic_public_play'))
            .width(20)
            .height(20)
            .fillColor('#FFFFFF')
        }
        .width(56)
        .height(56)
      } else {
        Image(this.medium.path)
          .width(56)
          .height(56)
          .objectFit(ImageFit.Cover)
          .borderRadius(4)
      }

      // Details column
      Column() {
        Text(this.medium.name)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          Text(this.formatSize(this.medium.size))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))

          Text(this.formatDate(this.medium.modified))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ left: 12 })
        }
        .margin({ top: 4 })

        // Type / duration info
        if (this.medium.isVideo()) {
          Text(this.formatDuration(this.medium.videoDuration))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      // Favorite star
      if (this.medium.isFavorite) {
        Image($r('app.media.ic_favor_filled'))
          .width(20)
          .height(20)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(this.isSelected
      ? $r('sys.color.ohos_id_color_activated_transparent')
      : $r('sys.color.ohos_id_color_background'))
  }

  // Format video duration in milliseconds to mm:ss
  private formatDuration(durationMs: number): string {
    const totalSeconds: number = Math.floor(durationMs / 1000)
    const minutes: number = Math.floor(totalSeconds / 60)
    const seconds: number = totalSeconds % 60
    const minuteStr: string = minutes.toString().padStart(2, '0')
    const secondStr: string = seconds.toString().padStart(2, '0')
    return minuteStr + ':' + secondStr
  }

  // Format file size to human-readable string
  private formatSize(bytes: number): string {
    if (bytes < 1024) {
      return bytes.toString() + ' B'
    } else if (bytes < 1024 * 1024) {
      const kb: number = Math.round(bytes / 1024 * 100) / 100
      return kb.toString() + ' KB'
    } else if (bytes < 1024 * 1024 * 1024) {
      const mb: number = Math.round(bytes / (1024 * 1024) * 100) / 100
      return mb.toString() + ' MB'
    } else {
      const gb: number = Math.round(bytes / (1024 * 1024 * 1024) * 100) / 100
      return gb.toString() + ' GB'
    }
  }

  // Format timestamp to readable date
  private formatDate(ts: number): string {
    if (ts <= 0) {
      return ''
    }
    const date: Date = new Date(ts)
    const year: number = date.getFullYear()
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0')
    const day: string = date.getDate().toString().padStart(2, '0')
    return year.toString() + '-' + month + '-' + day
  }
}

// =============================================================================
// ExifPanel.ets — Photo/Video details panel (T-025 + BUG-R7-4)
// Redesigned to match native HarmonyOS Gallery details style:
// - Card-based grouped layout
// - System icons + proper typography
// - All available info shown (no config flags blocking)
// =============================================================================

import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { Medium } from '../common/models/Medium'
import { TYPE_VIDEOS } from '../common/constants/Constants'

class ExifInfo {
  width: string = ''
  height: string = ''
  dateTaken: string = ''
  cameraModel: string = ''
  cameraMake: string = ''
  fNumber: string = ''
  exposureTime: string = ''
  iso: string = ''
  focalLength: string = ''
  gpsLatitude: string = ''
  gpsLongitude: string = ''
  gpsAltitude: string = ''
  fileSize: number = 0
  lastModified: number = 0
}

@Component
export struct ExifPanel {
  @Prop medium: Medium = new Medium()
  @Prop isVisible: boolean = true
  @State exifData: ExifInfo = new ExifInfo()
  @State isLoaded: boolean = false

  aboutToAppear(): void {
    this.loadExifData()
  }

  async loadExifData(): Promise<void> {
    const newExif: ExifInfo = new ExifInfo()

    // Get file size and modified time from medium data first
    newExif.fileSize = this.medium.size
    newExif.lastModified = this.medium.modified

    try {
      const file: fs.File = fs.openSync(this.medium.path, fs.OpenMode.READ_ONLY)
      const fd: number = file.fd

      try {
        // Try to get actual file stats via fd
        try {
          const stat: fs.Stat = fs.statSync(fd)
          if (stat.size > 0) {
            newExif.fileSize = stat.size
          }
          if (stat.mtime > 0) {
            newExif.lastModified = stat.mtime
          }
        } catch (statErr) {
          // Use medium data as fallback (already set above)
        }

        // Only extract EXIF from images (not videos)
        if (this.medium.type !== TYPE_VIDEOS) {
          const imageSource: image.ImageSource = image.createImageSource(fd)

          const props: Array<string> = [
            image.PropertyKey.IMAGE_WIDTH,
            image.PropertyKey.IMAGE_LENGTH,
            image.PropertyKey.DATE_TIME_ORIGINAL,
            image.PropertyKey.MODEL,
            image.PropertyKey.F_NUMBER,
            image.PropertyKey.EXPOSURE_TIME,
            image.PropertyKey.ISO_SPEED_RATINGS,
            image.PropertyKey.FOCAL_LENGTH,
            image.PropertyKey.GPS_LATITUDE,
            image.PropertyKey.GPS_LONGITUDE,
            image.PropertyKey.GPS_ALTITUDE
          ]

          for (let i: number = 0; i < props.length; i++) {
            try {
              const val: string = await imageSource.getImageProperty(props[i])
              if (val.length > 0 && val !== 'unknown') {
                if (props[i] === image.PropertyKey.IMAGE_WIDTH) newExif.width = val
                else if (props[i] === image.PropertyKey.IMAGE_LENGTH) newExif.height = val
                else if (props[i] === image.PropertyKey.DATE_TIME_ORIGINAL) newExif.dateTaken = val
                else if (props[i] === image.PropertyKey.MODEL) newExif.cameraModel = val
                else if (props[i] === image.PropertyKey.F_NUMBER) newExif.fNumber = val
                else if (props[i] === image.PropertyKey.EXPOSURE_TIME) newExif.exposureTime = val
                else if (props[i] === image.PropertyKey.ISO_SPEED_RATINGS) newExif.iso = val
                else if (props[i] === image.PropertyKey.FOCAL_LENGTH) newExif.focalLength = val
                else if (props[i] === image.PropertyKey.GPS_LATITUDE) newExif.gpsLatitude = val
                else if (props[i] === image.PropertyKey.GPS_LONGITUDE) newExif.gpsLongitude = val
                else if (props[i] === image.PropertyKey.GPS_ALTITUDE) newExif.gpsAltitude = val
              }
            } catch (e) {
              // Property not available — skip
            }
          }
          imageSource.release()
        }
      } finally {
        fs.closeSync(fd)
      }
    } catch (e) {
      // Failed to open file — use medium data only
    }

    this.exifData = newExif
    this.isLoaded = true
  }

  build() {
    if (this.isVisible) {
      Scroll() {
        Column({ space: 12 }) {
          // Header
          Text(this.medium.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // Basic info card
          this.buildBasicCard()

          // Camera info card — only show if has camera data
          if (this.hasCameraInfo()) {
            this.buildCameraCard()
          }

          // Location card — only show if has GPS data
          if (this.exifData.gpsLatitude.length > 0) {
            this.buildLocationCard()
          }
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: '60%' })
      .scrollBar(BarState.Off)
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
  }

  @Builder
  buildBasicCard() {
    Column({ space: 0 }) {
      Text('基本信息')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })
      Column({ space: 0 }) {
        this.buildBasicInfo()
      }
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .borderRadius(12)
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    }
    .width('100%')
  }

  @Builder
  buildCameraCard() {
    Column({ space: 0 }) {
      Text('拍摄参数')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })
      Column({ space: 0 }) {
        this.buildCameraInfo()
      }
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .borderRadius(12)
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    }
    .width('100%')
  }

  @Builder
  buildLocationCard() {
    Column({ space: 0 }) {
      Text('位置')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })
      Column({ space: 0 }) {
        this.buildLocationInfo()
      }
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .borderRadius(12)
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    }
    .width('100%')
  }

  @Builder
  buildBasicInfo() {
    // File type
    this.infoRow('类型', this.medium.type === TYPE_VIDEOS ? '视频' : '图片')

    // File size
    if (this.exifData.fileSize > 0 || this.medium.size > 0) {
      this.infoRow('大小', this.formatSize(this.exifData.fileSize > 0 ? this.exifData.fileSize : this.medium.size))
    }

    // Resolution
    if (this.exifData.width.length > 0 && this.exifData.height.length > 0) {
      this.infoRow('分辨率', this.exifData.width + ' x ' + this.exifData.height)
    }

    // Date taken
    if (this.exifData.dateTaken.length > 0) {
      this.infoRow('拍摄时间', this.exifData.dateTaken)
    }

    // Last modified
    if (this.exifData.lastModified > 0 || this.medium.modified > 0) {
      this.infoRow('修改时间', this.formatDate(this.exifData.lastModified > 0 ? this.exifData.lastModified : this.medium.modified))
    }

    // Path
    this.infoRow('路径', this.medium.path)
  }

  @Builder
  buildCameraInfo() {
    if (this.exifData.cameraModel.length > 0) {
      this.infoRow('设备', this.exifData.cameraModel)
    }
    if (this.exifData.fNumber.length > 0) {
      this.infoRow('光圈', 'f/' + this.exifData.fNumber)
    }
    if (this.exifData.exposureTime.length > 0) {
      this.infoRow('快门', this.exifData.exposureTime + 's')
    }
    if (this.exifData.iso.length > 0) {
      this.infoRow('ISO', this.exifData.iso)
    }
    if (this.exifData.focalLength.length > 0) {
      this.infoRow('焦距', this.exifData.focalLength + 'mm')
    }
  }

  @Builder
  buildLocationInfo() {
    this.infoRow('纬度', this.exifData.gpsLatitude)
    this.infoRow('经度', this.exifData.gpsLongitude)
    if (this.exifData.gpsAltitude.length > 0) {
      this.infoRow('海拔', this.exifData.gpsAltitude + 'm')
    }
  }

  private hasCameraInfo(): boolean {
    return this.exifData.cameraModel.length > 0 ||
      this.exifData.fNumber.length > 0 ||
      this.exifData.exposureTime.length > 0 ||
      this.exifData.iso.length > 0 ||
      this.exifData.focalLength.length > 0
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width(72)
        .flexShrink(0)
      Text(value)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 10, bottom: 10 })
  }

  private formatSize(bytes: number): string {
    if (bytes <= 0) return ''
    if (bytes < 1024) return bytes.toString() + ' B'
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB'
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + ' MB'
    return (bytes / 1073741824).toFixed(1) + ' GB'
  }

  private formatDate(ts: number): string {
    if (ts <= 0) return ''
    const date: Date = new Date(ts)
    const y: number = date.getFullYear()
    const mo: string = (date.getMonth() + 1).toString().padStart(2, '0')
    const d: string = date.getDate().toString().padStart(2, '0')
    const h: string = date.getHours().toString().padStart(2, '0')
    const mi: string = date.getMinutes().toString().padStart(2, '0')
    return y.toString() + '/' + mo + '/' + d + ' ' + h + ':' + mi
  }
}

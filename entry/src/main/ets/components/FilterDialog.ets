// =============================================================================
// FilterDialog.ets — Custom dialog for filtering media types
// =============================================================================

import {
  TYPE_IMAGES,
  TYPE_VIDEOS,
  TYPE_GIFS,
  TYPE_RAWS,
  TYPE_SVGS
} from '../common/constants/Constants'

interface FilterOption {
  label: string
  value: number
}

@CustomDialog
export struct FilterDialog {
  controller: CustomDialogController
  currentFilter: number = TYPE_IMAGES | TYPE_VIDEOS | TYPE_GIFS | TYPE_RAWS | TYPE_SVGS
  onFilterChanged: (filter: number) => void = (_filter: number) => {}

  @State showImages: boolean = true
  @State showVideos: boolean = true
  @State showGifs: boolean = true
  @State showRaws: boolean = true
  @State showSvgs: boolean = true

  aboutToAppear(): void {
    this.showImages = (this.currentFilter & TYPE_IMAGES) !== 0
    this.showVideos = (this.currentFilter & TYPE_VIDEOS) !== 0
    this.showGifs = (this.currentFilter & TYPE_GIFS) !== 0
    this.showRaws = (this.currentFilter & TYPE_RAWS) !== 0
    this.showSvgs = (this.currentFilter & TYPE_SVGS) !== 0
  }

  build() {
    Column() {
      Text($r('app.string.filter_media_types'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .padding({ bottom: 16 })

      this.filterRow($r('app.string.images'), this.showImages, (isOn: boolean) => {
        this.showImages = isOn
      })
      this.filterRow($r('app.string.videos'), this.showVideos, (isOn: boolean) => {
        this.showVideos = isOn
      })
      this.filterRow($r('app.string.gifs'), this.showGifs, (isOn: boolean) => {
        this.showGifs = isOn
      })
      this.filterRow($r('app.string.raw_images'), this.showRaws, (isOn: boolean) => {
        this.showRaws = isOn
      })
      this.filterRow($r('app.string.svgs'), this.showSvgs, (isOn: boolean) => {
        this.showSvgs = isOn
      })

      Row() {
        Button($r('app.string.cancel'))
          .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .margin({ right: 8 })
          .onClick(() => {
            this.controller.close()
          })

        Button($r('app.string.ok'))
          .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            let filter: number = 0
            if (this.showImages) {
              filter = filter | TYPE_IMAGES
            }
            if (this.showVideos) {
              filter = filter | TYPE_VIDEOS
            }
            if (this.showGifs) {
              filter = filter | TYPE_GIFS
            }
            if (this.showRaws) {
              filter = filter | TYPE_RAWS
            }
            if (this.showSvgs) {
              filter = filter | TYPE_SVGS
            }
            if (filter === 0) {
              this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.select_at_least_one') })
              return
            }
            this.onFilterChanged(filter)
            this.controller.close()
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .padding(24)
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
  }

  @Builder
  filterRow(label: string | Resource, isChecked: boolean, onChange: (isOn: boolean) => void) {
    Row() {
      Checkbox()
        .select(isChecked)
        .onChange((value: boolean) => {
          onChange(value)
        })
      Text(label)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ left: 8 })
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }
}

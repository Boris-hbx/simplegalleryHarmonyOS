@Component
export struct SelectionToolbar {
  selectedCount: number = 0
  onSelectAll: () => void = () => {}
  onDeselectAll: () => void = () => {}
  onDelete: () => void = () => {}
  onShare: () => void = () => {}
  onClose: () => void = () => {}

  build() {
    Row() {
      Image($r('sys.media.ohos_ic_public_cancel'))
        .width(24)
        .height(24)
        .fillColor($r('sys.color.ohos_id_color_text_primary'))
        .onClick(() => {
          this.onClose()
        })

      Text(this.selectedCount.toString() + ' selected')
        .fontSize(18)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ left: 16 })
        .layoutWeight(1)

      Image($r('sys.media.ohos_ic_public_select_all'))
        .width(24)
        .height(24)
        .fillColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ right: 16 })
        .onClick(() => {
          this.onSelectAll()
        })

      Image($r('sys.media.ohos_ic_public_delete'))
        .width(24)
        .height(24)
        .fillColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ right: 16 })
        .onClick(() => {
          this.onDelete()
        })

      Image($r('sys.media.ohos_ic_public_share'))
        .width(24)
        .height(24)
        .fillColor($r('sys.color.ohos_id_color_text_primary'))
        .onClick(() => {
          this.onShare()
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}

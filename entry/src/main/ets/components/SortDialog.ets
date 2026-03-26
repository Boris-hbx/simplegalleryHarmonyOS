// =============================================================================
// SortDialog.ets — Custom dialog for sorting directories
// =============================================================================

import {
  SORT_BY_NAME,
  SORT_BY_DATE_MODIFIED,
  SORT_BY_SIZE,
  SORT_BY_DATE_TAKEN,
  SORT_BY_RANDOM,
  SORT_BY_PATH,
  SORT_DESCENDING
} from '../common/constants/Constants'

interface SortOption {
  label: string
  value: number
}

@CustomDialog
export struct SortDialog {
  controller: CustomDialogController
  currentSorting: number = SORT_BY_DATE_MODIFIED | SORT_DESCENDING
  onSortChanged: (sorting: number) => void = (_sorting: number) => {}

  @State selectedSortBy: number = SORT_BY_DATE_MODIFIED
  @State isDescending: boolean = true

  private sortOptions: SortOption[] = []

  private initSortOptions(): void {
    this.sortOptions = [
      { label: this.getStr($r('app.string.sort_name').id), value: SORT_BY_NAME },
      { label: this.getStr($r('app.string.sort_date_modified').id), value: SORT_BY_DATE_MODIFIED },
      { label: this.getStr($r('app.string.sort_date_taken').id), value: SORT_BY_DATE_TAKEN },
      { label: this.getStr($r('app.string.sort_size').id), value: SORT_BY_SIZE },
      { label: this.getStr($r('app.string.sort_path').id), value: SORT_BY_PATH },
      { label: this.getStr($r('app.string.sort_random').id), value: SORT_BY_RANDOM }
    ]
  }

  private getStr(id: number): string {
    try {
      return getContext(this).resourceManager.getStringSync(id)
    } catch (e) {
      return ''
    }
  }

  aboutToAppear(): void {
    this.initSortOptions()
    // Extract sort field (mask off the SORT_DESCENDING flag)
    this.isDescending = (this.currentSorting & SORT_DESCENDING) !== 0
    const sortField: number = this.currentSorting & ~SORT_DESCENDING
    if (sortField > 0) {
      this.selectedSortBy = sortField
    } else {
      this.selectedSortBy = SORT_BY_DATE_MODIFIED
    }
  }

  build() {
    Column() {
      Text($r('app.string.sort_by'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .padding({ bottom: 16 })

      ForEach(this.sortOptions, (option: SortOption) => {
        Row() {
          Radio({ value: option.label, group: 'sortGroup' })
            .checked(this.selectedSortBy === option.value)
            .onChange((isChecked: boolean) => {
              if (isChecked) {
                this.selectedSortBy = option.value
              }
            })
          Text(option.label)
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ left: 8 })
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
      }, (option: SortOption) => option.label)

      Divider()
        .color($r('sys.color.ohos_id_color_list_separator'))
        .margin({ top: 8, bottom: 8 })

      Row() {
        Text($r('app.string.descending'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.isDescending })
          .onChange((isOn: boolean) => {
            this.isDescending = isOn
          })
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center)

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
            let sorting: number = this.selectedSortBy
            if (this.isDescending) {
              sorting = sorting | SORT_DESCENDING
            }
            this.onSortChanged(sorting)
            this.controller.close()
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .padding(24)
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
  }
}

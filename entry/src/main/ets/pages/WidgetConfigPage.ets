// =============================================================================
// WidgetConfigPage.ets — Folder picker for widget configuration (T-036)
// FR-058: Display folder list for widget configuration
// FR-059: Select folder for widget
// FR-060: Save widget configuration to database
// FR-061: Widget renders immediately after configuration
// =============================================================================

import { router } from '@kit.ArkUI'
import { formBindingData, formProvider } from '@kit.FormKit'
import { WidgetsDao } from '../datastore/dao/WidgetsDao'
import { Widget } from '../common/models/Widget'
import { DirectoryDao } from '../datastore/dao/DirectoryDao'
import { Directory } from '../common/models/Directory'

interface WidgetConfigParams {
  formId: string
}

@Entry
@Component
struct WidgetConfigPage {
  @State formId: string = ''
  @State directories: Directory[] = []
  @State selectedIndex: number = -1
  @State isLoading: boolean = true

  aboutToAppear(): void {
    const params: WidgetConfigParams | null = router.getParams() as WidgetConfigParams
    if (params !== null && params !== undefined) {
      this.formId = params.formId
    }
    this.loadDirectories()
  }

  async loadDirectories(): Promise<void> {
    this.isLoading = true
    try {
      const directoryDao: DirectoryDao = new DirectoryDao()
      this.directories = await directoryDao.getAll()
    } catch (e) {
      console.error('WidgetConfigPage: failed to load directories')
    }
    this.isLoading = false
  }

  async saveConfiguration(): Promise<void> {
    if (this.selectedIndex < 0 || this.selectedIndex >= this.directories.length) {
      return
    }
    const selectedDir: Directory = this.directories[this.selectedIndex]
    const folderPath: string = selectedDir.path

    try {
      // Save to database
      const widgetsDao: WidgetsDao = new WidgetsDao()
      const widget: Widget = new Widget(0, parseInt(this.formId), folderPath)
      await widgetsDao.insertOrUpdate(widget)

      // Update the form with initial data
      const lastSlashIndex: number = folderPath.lastIndexOf('/')
      const folderName: string = lastSlashIndex >= 0
        ? folderPath.substring(lastSlashIndex + 1)
        : folderPath
      const bindingData: Record<string, string | boolean> = {
        'thumbnailUri': selectedDir.tmb,
        'folderName': folderName,
        'folderPath': folderPath,
        'showFolderName': true
      }
      const data: formBindingData.FormBindingData = formBindingData.createFormBindingData(bindingData)
      await formProvider.updateForm(this.formId, data)

      // Close page
      router.back()
    } catch (e) {
      console.error('WidgetConfigPage: failed to save configuration')
    }
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
        .width(40)
        .height(40)
        .onClick(() => {
          router.back()
        })

        Text($r('app.string.configure_widget'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .margin({ top: 100 })
      } else if (this.directories.length === 0) {
        Text($r('app.string.no_folders_found'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ top: 100 })
      } else {
        // Folder grid
        Grid() {
          ForEach(this.directories, (dir: Directory, index: number) => {
            GridItem() {
              Column() {
                Image(dir.tmb)
                  .width('100%')
                  .aspectRatio(1)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(8)
                  .border({
                    width: this.selectedIndex === index ? 3 : 0,
                    color: $r('sys.color.ohos_id_color_activated')
                  })

                Text(dir.name)
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 })

                Text(dir.mediaCnt.toString() + ' items')
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .padding(4)
            }
            .onClick(() => {
              this.selectedIndex = index
            })
          }, (dir: Directory) => dir.path)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .padding(8)
        .layoutWeight(1)
      }

      // Save button
      Button($r('app.string.save'))
        .width('80%')
        .margin({ bottom: 16 })
        .enabled(this.selectedIndex >= 0)
        .onClick(() => {
          this.saveConfiguration()
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}

// =============================================================================
// IncludedFoldersPage.ets — Manage included folders list
// T-033: Folder Management Pages
// =============================================================================

import { router } from '@kit.ArkUI'
import { ConfigManager } from '../datastore/ConfigManager'

@Entry
@Component
struct IncludedFoldersPage {
  @State folders: string[] = []
  @State showAddDialog: boolean = false
  @State newFolderPath: string = ''

  aboutToAppear(): void {
    this.loadFolders()
  }

  loadFolders(): void {
    const config: ConfigManager = ConfigManager.getInstance()
    const folderSet: Set<string> = config.includedFolders
    this.folders = Array.from(folderSet)
  }

  addFolder(path: string): void {
    if (path.length === 0) {
      return
    }
    const config: ConfigManager = ConfigManager.getInstance()
    config.addIncludedFolders(new Set<string>([path]))
    this.loadFolders()
  }

  removeFolder(path: string): void {
    const config: ConfigManager = ConfigManager.getInstance()
    config.removeIncludedFolders(new Set<string>([path]))
    this.loadFolders()
  }

  @Builder
  swipeActionEnd(folder: string) {
    Row() {
      Button($r('app.string.remove'))
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
        .backgroundColor($r('sys.color.ohos_id_color_warning'))
        .height(48)
        .onClick(() => {
          this.removeFolder(folder)
        })
    }
    .padding({ left: 8, right: 8 })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      // Top toolbar
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

        Text($r('app.string.included_folders_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
          .layoutWeight(1)

        Button() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
        .width(40)
        .height(40)
        .onClick(() => {
          this.newFolderPath = ''
          this.showAddDialog = true
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)

      if (this.folders.length === 0) {
        Column() {
          Text($r('app.string.no_included_folders'))
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .opacity(0.6)
          Text($r('app.string.tap_plus_to_add'))
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .opacity(0.4)
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        List() {
          ForEach(this.folders, (folder: string) => {
            ListItem() {
              Row() {
                SymbolGlyph($r('sys.symbol.folder'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  .margin({ right: 12 })
                Text(folder)
                  .fontSize(16)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            }
            .swipeAction({ end: () => { this.swipeActionEnd(folder) } })
          }, (folder: string): string => folder)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .bindSheet($$this.showAddDialog, this.addFolderSheet(), {
      height: SheetSize.FIT_CONTENT,
      title: { title: 'Add Folder' }
    })
  }

  @Builder
  addFolderSheet() {
    Column() {
      TextInput({ placeholder: $r('app.string.enter_folder_path'), text: this.newFolderPath })
        .width('100%')
        .onChange((value: string) => {
          this.newFolderPath = value
        })
        .margin({ bottom: 16 })

      Row() {
        Button($r('app.string.cancel'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .layoutWeight(1)
          .onClick(() => {
            this.showAddDialog = false
          })

        Button($r('app.string.add'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
          .layoutWeight(1)
          .onClick(() => {
            this.addFolder(this.newFolderPath)
            this.showAddDialog = false
          })
      }
      .width('100%')
    }
    .padding(16)
    .width('100%')
  }
}

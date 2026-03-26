// =============================================================================
// HiddenFoldersPage.ets — View and unhide hidden folders (.nomedia)
// T-033: Folder Management Pages
// =============================================================================

import { router } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'

@Entry
@Component
struct HiddenFoldersPage {
  @State hiddenFolders: string[] = []
  @State isScanning: boolean = false

  aboutToAppear(): void {
    this.scanHiddenFolders()
  }

  scanHiddenFolders(): void {
    this.isScanning = true
    const result: string[] = []
    const searchPaths: string[] = [
      '/storage/media/100/local/files',
      '/storage/Users/currentUser'
    ]
    for (let i: number = 0; i < searchPaths.length; i++) {
      this.scanDirectory(searchPaths[i], result, 0)
    }
    this.hiddenFolders = result
    this.isScanning = false
  }

  private scanDirectory(dirPath: string, result: string[], depth: number): void {
    if (depth > 5) {
      return
    }
    try {
      const nomediaPath: string = dirPath + '/.nomedia'
      try {
        fileIo.accessSync(nomediaPath)
        result.push(dirPath)
      } catch (accessErr) {
        // .nomedia does not exist in this directory, continue scanning
      }
      // Check if directory name starts with dot (hidden by convention)
      const lastSlash: number = dirPath.lastIndexOf('/')
      if (lastSlash >= 0) {
        const dirName: string = dirPath.substring(lastSlash + 1)
        if (dirName.length > 0 && dirName.charAt(0) === '.') {
          // Avoid duplicates
          if (result.indexOf(dirPath) < 0) {
            result.push(dirPath)
          }
        }
      }
      // Recurse into subdirectories
      try {
        const entries: string[] = fileIo.listFileSync(dirPath)
        for (let i: number = 0; i < entries.length; i++) {
          const childPath: string = dirPath + '/' + entries[i]
          try {
            const stat: fileIo.Stat = fileIo.statSync(childPath)
            if (stat.isDirectory()) {
              this.scanDirectory(childPath, result, depth + 1)
            }
          } catch (statErr) {
            // Cannot stat entry, skip
          }
        }
      } catch (dirErr) {
        // Cannot read directory, skip
      }
    } catch (e) {
      // Skip directories we cannot access
    }
  }

  unhideFolder(path: string): void {
    const nomediaPath: string = path + '/.nomedia'
    try {
      fileIo.unlinkSync(nomediaPath)
    } catch (e) {
      // .nomedia file may not exist (folder hidden by dot-prefix)
    }
    // Refresh the list
    const updated: string[] = []
    for (let i: number = 0; i < this.hiddenFolders.length; i++) {
      if (this.hiddenFolders[i] !== path) {
        updated.push(this.hiddenFolders[i])
      }
    }
    this.hiddenFolders = updated
  }

  @Builder
  swipeActionEnd(folder: string) {
    Row() {
      Button($r('app.string.unhide'))
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
        .backgroundColor($r('sys.color.ohos_id_color_activated'))
        .height(48)
        .onClick(() => {
          this.unhideFolder(folder)
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

        Text($r('app.string.hidden_folders_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
          .layoutWeight(1)

        Button() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
        .width(40)
        .height(40)
        .onClick(() => {
          this.scanHiddenFolders()
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)

      if (this.isScanning) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
          Text($r('app.string.scanning_hidden_folders'))
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else if (this.hiddenFolders.length === 0) {
        Column() {
          Text($r('app.string.no_hidden_folders_found'))
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .opacity(0.6)
          Text($r('app.string.hidden_folders_hint'))
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .opacity(0.4)
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        List() {
          ForEach(this.hiddenFolders, (folder: string) => {
            ListItem() {
              Row() {
                SymbolGlyph($r('sys.symbol.folder'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  .margin({ right: 12 })
                Column() {
                  Text(folder)
                    .fontSize(16)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text($r('app.string.hidden_label'))
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
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
  }
}

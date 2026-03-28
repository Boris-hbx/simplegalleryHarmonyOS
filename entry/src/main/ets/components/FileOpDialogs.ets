// =============================================================================
// FileOpDialogs.ets — Reusable dialogs for file operations
// =============================================================================

import { DirectoryDao } from '../datastore/dao/DirectoryDao'
import { Directory } from '../common/models/Directory'
import { ConfigManager } from '../datastore/ConfigManager'
import { MediaScanner } from '../media/MediaScanner'

// =============================================================================
// RenameDialog — Text input for new file name, OK / Cancel
// =============================================================================

@CustomDialog
export struct RenameDialog {
  controller: CustomDialogController
  currentName: string = ''
  onConfirm: (newName: string) => void = (_newName: string) => {}

  @State newName: string = ''

  aboutToAppear(): void {
    this.newName = this.currentName
  }

  build() {
    Column() {
      Text($r('app.string.rename'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .padding({ bottom: 16 })

      TextInput({ text: this.newName, placeholder: $r('app.string.enter_new_name') })
        .width('100%')
        .onChange((value: string) => {
          this.newName = value
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
            const trimmed: string = this.newName.trim()
            if (trimmed.length === 0) {
              return
            }
            this.onConfirm(trimmed)
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

// =============================================================================
// DeleteConfirmDialog — "Delete N items?" with optional skip-recycle-bin checkbox
// =============================================================================

@CustomDialog
export struct DeleteConfirmDialog {
  controller: CustomDialogController
  fileCount: number = 1
  showRecycleBinOption: boolean = true
  onConfirm: (skipRecycleBin: boolean) => void = (_skipRecycleBin: boolean) => {}

  @State skipRecycleBin: boolean = false

  private getStr(resId: number): string {
    try {
      return getContext(this).resourceManager.getStringSync(resId)
    } catch (e) {
      return ''
    }
  }

  aboutToAppear(): void {
    const config: ConfigManager = ConfigManager.getInstance()
    this.showRecycleBinOption = config.useRecycleBin
  }

  build() {
    Column() {
      Text(this.getStr($r('app.string.delete_confirm_question').id).replace('%d', this.fileCount.toString()))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .padding({ bottom: 8 })

      Text($r('app.string.action_cannot_be_undone'))
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .padding({ bottom: 16 })

      if (this.showRecycleBinOption) {
        Row() {
          Checkbox()
            .select(this.skipRecycleBin)
            .onChange((value: boolean) => {
              this.skipRecycleBin = value
            })
          Text($r('app.string.skip_recycle_bin'))
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ left: 8 })
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
      }

      Row() {
        Button($r('app.string.cancel'))
          .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .margin({ right: 8 })
          .onClick(() => {
            this.controller.close()
          })

        Button($r('app.string.delete_action'))
          .fontColor($r('sys.color.ohos_id_color_warning'))
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.onConfirm(this.skipRecycleBin)
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

// =============================================================================
// CopyMoveDialog — Folder picker for copy/move destination
// =============================================================================

@CustomDialog
export struct CopyMoveDialog {
  controller: CustomDialogController
  title: string = 'Select destination'
  onFolderSelected: (folderPath: string) => void = (_folderPath: string) => {}

  @State directories: Array<Directory> = []
  @State selectedIndex: number = -1

  aboutToAppear(): void {
    this.loadDirectories()
  }

  // BUG-041b: Use MediaScanner (photoAccessHelper) instead of empty internal DirectoryDao
  private async loadDirectories(): Promise<void> {
    try {
      const context: Context = getContext(this)
      const scanner: MediaScanner = new MediaScanner(context)
      const config: ConfigManager = ConfigManager.getInstance()
      const allDirs: Array<Directory> = await scanner.getDirectories(config.filterMedia, config.directorySorting)
      const filtered: Array<Directory> = []
      for (let i: number = 0; i < allDirs.length; i++) {
        const dir: Directory = allDirs[i]
        if (!dir.areFavorites() && !dir.isRecycleBin()) {
          filtered.push(dir)
        }
      }
      this.directories = filtered
    } catch (e) {
      console.error('CopyMoveDialog: failed to load directories: ' + (e as Error).message)
    }
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .padding({ bottom: 16 })

      if (this.directories.length === 0) {
        Text($r('app.string.no_folders_available'))
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 16, bottom: 16 })
      } else {
        List() {
          ForEach(this.directories, (dir: Directory, index: number) => {
            ListItem() {
              Row() {
                Text('📁')
                  .fontSize(20)
                  .margin({ right: 12 })

                Column() {
                  Text(dir.name)
                    .fontSize(16)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(dir.path)
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                if (this.selectedIndex === index) {
                  Image($r('sys.media.ohos_ic_public_ok'))
                    .width(20)
                    .height(20)
                    .fillColor($r('sys.color.ohos_id_color_primary'))
                }
              }
              .width('100%')
              .height(56)
              .padding({ left: 8, right: 8 })
              .borderRadius(8)
              .backgroundColor(this.selectedIndex === index
                ? $r('sys.color.ohos_id_color_activated')
                : $r('sys.color.ohos_id_color_background_transparent'))
              .onClick(() => {
                this.selectedIndex = index
              })
            }
          })
        }
        .width('100%')
        .height(280)
        .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
      }

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
          .enabled(this.selectedIndex >= 0)
          .opacity(this.selectedIndex >= 0 ? 1.0 : 0.4)
          .onClick(() => {
            if (this.selectedIndex >= 0 && this.selectedIndex < this.directories.length) {
              const selected: Directory = this.directories[this.selectedIndex]
              this.onFolderSelected(selected.path)
              this.controller.close()
            }
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .padding(24)
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
  }
}

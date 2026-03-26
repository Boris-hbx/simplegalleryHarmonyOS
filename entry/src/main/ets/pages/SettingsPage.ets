// =============================================================================
// SettingsPage.ets — Full settings UI for Simple Gallery (HarmonyOS)
// T-028: All user-facing preferences organized into sections
// =============================================================================

import { router } from '@kit.ArkUI'
import { picker } from '@kit.CoreFileKit'
import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { ConfigManager } from '../datastore/ConfigManager'
import { SettingsExporter } from '../common/utils/SettingsExporter'
import { FavoritesExporter } from '../common/utils/FavoritesExporter'
import {
  ROUNDED_CORNERS_NONE,
  ROUNDED_CORNERS_SMALL,
  ROUNDED_CORNERS_BIG,
  FOLDER_STYLE_SQUARE,
  FOLDER_STYLE_ROUNDED_CORNERS,
  FOLDER_MEDIA_CNT_LINE,
  FOLDER_MEDIA_CNT_BRACKETS,
  FOLDER_MEDIA_CNT_NONE,
  ROTATE_BY_SYSTEM_SETTING,
  ROTATE_BY_DEVICE_ROTATION,
  ROTATE_BY_ASPECT_RATIO,
  PRIORITY_SPEED,
  PRIORITY_COMPROMISE,
  PRIORITY_VALIDITY
} from '../common/constants/Constants'

@Entry
@Component
struct SettingsPage {
  // ---- General ----
  @State showHiddenMedia: boolean = false
  @State showAll: boolean = false
  @State useRecycleBin: boolean = true
  @State showRecycleBinAtFolders: boolean = true
  @State showRecycleBinLast: boolean = false
  @State deleteEmptyFolders: boolean = false
  @State searchAllFilesByDefault: boolean = false
  @State fileLoadingPriority: number = PRIORITY_SPEED

  // ---- Thumbnails ----
  @State cropThumbnails: boolean = true
  @State showThumbnailVideoDuration: boolean = false
  @State showThumbnailFileTypes: boolean = true
  @State markFavoriteItems: boolean = true
  @State fileRoundedCorners: number = ROUNDED_CORNERS_BIG
  @State folderThumbnailStyle: number = FOLDER_STYLE_ROUNDED_CORNERS
  @State folderMediaCount: number = FOLDER_MEDIA_CNT_LINE
  @State thumbnailSpacing: number = 1

  // ---- Display ----
  @State displayFileNames: boolean = false
  @State showExtendedDetails: boolean = false
  @State hideExtendedDetails: boolean = false
  @State limitFolderTitle: boolean = false

  // ---- Videos ----
  @State autoplayVideos: boolean = false
  @State loopVideos: boolean = false
  @State openVideosOnSeparateScreen: boolean = false
  @State rememberLastVideoPosition: boolean = false
  @State animateGifs: boolean = false

  // ---- Fullscreen Media ----
  @State blackBackground: boolean = false
  @State hideSystemUI: boolean = false
  @State showNotch: boolean = true
  @State maxBrightness: boolean = false
  @State allowInstantChange: boolean = false
  @State allowPhotoGestures: boolean = false
  @State allowVideoGestures: boolean = true
  @State allowDownGesture: boolean = true
  @State screenRotation: number = ROTATE_BY_SYSTEM_SETTING

  // ---- Deep Zoomable Images ----
  @State allowZoomingImages: boolean = true
  @State allowRotatingWithGestures: boolean = true
  @State allowOneToOneZoom: boolean = false
  @State showHighestQuality: boolean = false

  // ---- Recycle Bin ----
  @State bottomActions: boolean = true

  // ---- Storage (T-058) ----
  @State cacheSize: string = '...'

  private getStr(resId: number): string {
    try {
      return getContext(this).resourceManager.getStringSync(resId)
    } catch (e) {
      return ''
    }
  }

  aboutToAppear(): void {
    const config: ConfigManager = ConfigManager.getInstance()

    // General
    this.showHiddenMedia = config.showHiddenMedia
    this.showAll = config.showAll
    this.useRecycleBin = config.useRecycleBin
    this.showRecycleBinAtFolders = config.showRecycleBinAtFolders
    this.showRecycleBinLast = config.showRecycleBinLast
    this.deleteEmptyFolders = config.deleteEmptyFolders
    this.searchAllFilesByDefault = config.searchAllFilesByDefault
    this.fileLoadingPriority = config.fileLoadingPriority

    // Thumbnails
    this.cropThumbnails = config.cropThumbnails
    this.showThumbnailVideoDuration = config.showThumbnailVideoDuration
    this.showThumbnailFileTypes = config.showThumbnailFileTypes
    this.markFavoriteItems = config.markFavoriteItems
    this.fileRoundedCorners = config.fileRoundedCorners
    this.folderThumbnailStyle = config.folderThumbnailStyle
    this.folderMediaCount = config.folderMediaCount
    this.thumbnailSpacing = config.thumbnailSpacing

    // Display
    this.displayFileNames = config.displayFileNames
    this.showExtendedDetails = config.showExtendedDetails
    this.hideExtendedDetails = config.hideExtendedDetails
    this.limitFolderTitle = config.limitFolderTitle

    // Videos
    this.autoplayVideos = config.autoplayVideos
    this.loopVideos = config.loopVideos
    this.openVideosOnSeparateScreen = config.openVideosOnSeparateScreen
    this.rememberLastVideoPosition = config.rememberLastVideoPosition
    this.animateGifs = config.animateGifs

    // Fullscreen Media
    this.blackBackground = config.blackBackground
    this.hideSystemUI = config.hideSystemUI
    this.showNotch = config.showNotch
    this.maxBrightness = config.maxBrightness
    this.allowInstantChange = config.allowInstantChange
    this.allowPhotoGestures = config.allowPhotoGestures
    this.allowVideoGestures = config.allowVideoGestures
    this.allowDownGesture = config.allowDownGesture
    this.screenRotation = config.screenRotation

    // Deep Zoomable Images
    this.allowZoomingImages = config.allowZoomingImages
    this.allowRotatingWithGestures = config.allowRotatingWithGestures
    this.allowOneToOneZoom = config.allowOneToOneZoom
    this.showHighestQuality = config.showHighestQuality

    // Bottom actions
    this.bottomActions = config.bottomActions

    // Cache size
    this.calculateCacheSize()
  }

  private calculateCacheSize(): void {
    try {
      const cacheDir: string = getContext(this).cacheDir
      const files: string[] = fileIo.listFileSync(cacheDir)
      let totalSize: number = 0
      for (let i: number = 0; i < files.length; i++) {
        try {
          const stat: fileIo.Stat = fileIo.statSync(cacheDir + '/' + files[i])
          totalSize += stat.size
        } catch (e) {
          // skip files that can't be stat'd
        }
      }
      this.cacheSize = this.formatSize(totalSize)
    } catch (e) {
      this.cacheSize = '0 B'
    }
  }

  private formatSize(bytes: number): string {
    if (bytes <= 0) {
      return '0 B'
    }
    const units: string[] = ['B', 'KB', 'MB', 'GB']
    let unitIndex: number = 0
    let size: number = bytes
    while (size >= 1024 && unitIndex < units.length - 1) {
      size = size / 1024
      unitIndex++
    }
    if (unitIndex === 0) {
      return size.toFixed(0) + ' ' + units[unitIndex]
    }
    return size.toFixed(2) + ' ' + units[unitIndex]
  }

  private clearCache(): void {
    try {
      const cacheDir: string = getContext(this).cacheDir
      const files: string[] = fileIo.listFileSync(cacheDir)
      for (let i: number = 0; i < files.length; i++) {
        try {
          fileIo.unlinkSync(cacheDir + '/' + files[i])
        } catch (e) {
          // skip files that can't be deleted
        }
      }
      this.cacheSize = '0 B'
      this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.cache_cleared') })
    } catch (e) {
      this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.cache_clear_failed') })
    }
  }

  // ===========================================================================
  // Reusable Builders
  // ===========================================================================

  @Builder
  sectionHeader(title: string | Resource) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width('100%')
      .padding({ left: 16, top: 24, bottom: 8 })
  }

  // Design decision (T-059): Using Toggle (ToggleType.Switch) instead of Checkbox.
  // HarmonyOS design language uses Toggle switches for boolean settings, not Android-style checkboxes.
  @Builder
  settingToggle(label: string | Resource, value: boolean, onChange: (val: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((isOn: boolean) => {
          onChange(isOn)
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  selectorItem(label: string | Resource, currentValue: string, onClick: () => void) {
    Row() {
      Column() {
        Text(label)
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Text(currentValue)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      onClick()
    })
  }

  @Builder
  sliderItem(label: string | Resource, value: number, min: number, max: number, step: number,
    onChange: (val: number) => void) {
    Column() {
      Row() {
        Text(label)
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
        Text('' + value)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .width('100%')

      Slider({ value: value, min: min, max: max, step: step, style: SliderStyle.OutSet })
        .width('100%')
        .onChange((val: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            onChange(Math.round(val))
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  // ===========================================================================
  // Helper: label lookups for selector values
  // ===========================================================================

  getRoundedCornersLabel(): string {
    if (this.fileRoundedCorners === ROUNDED_CORNERS_NONE) {
      return this.getStr($r('app.string.none_option').id)
    } else if (this.fileRoundedCorners === ROUNDED_CORNERS_SMALL) {
      return this.getStr($r('app.string.small_option').id)
    } else {
      return this.getStr($r('app.string.big_option').id)
    }
  }

  getFolderStyleLabel(): string {
    if (this.folderThumbnailStyle === FOLDER_STYLE_SQUARE) {
      return this.getStr($r('app.string.square_option').id)
    } else {
      return this.getStr($r('app.string.rounded_option').id)
    }
  }

  getFolderMediaCountLabel(): string {
    if (this.folderMediaCount === FOLDER_MEDIA_CNT_LINE) {
      return this.getStr($r('app.string.line_option').id)
    } else if (this.folderMediaCount === FOLDER_MEDIA_CNT_BRACKETS) {
      return this.getStr($r('app.string.brackets_option').id)
    } else {
      return this.getStr($r('app.string.none_option').id)
    }
  }

  getScreenRotationLabel(): string {
    if (this.screenRotation === ROTATE_BY_SYSTEM_SETTING) {
      return this.getStr($r('app.string.system_setting').id)
    } else if (this.screenRotation === ROTATE_BY_DEVICE_ROTATION) {
      return this.getStr($r('app.string.device_rotation').id)
    } else {
      return this.getStr($r('app.string.aspect_ratio_option').id)
    }
  }

  getFileLoadingPriorityLabel(): string {
    if (this.fileLoadingPriority === PRIORITY_SPEED) {
      return this.getStr($r('app.string.speed_option').id)
    } else if (this.fileLoadingPriority === PRIORITY_COMPROMISE) {
      return this.getStr($r('app.string.compromise_option').id)
    } else {
      return this.getStr($r('app.string.validity_option').id)
    }
  }

  // ===========================================================================
  // Selector dialog helpers
  // ===========================================================================

  showRoundedCornersDialog(): void {
    const options: string[] = [this.getStr($r('app.string.none_option').id), this.getStr($r('app.string.small_option').id), this.getStr($r('app.string.big_option').id)]
    const values: number[] = [ROUNDED_CORNERS_NONE, ROUNDED_CORNERS_SMALL, ROUNDED_CORNERS_BIG]
    let selectedIdx: number = 0
    for (let i: number = 0; i < values.length; i++) {
      if (values[i] === this.fileRoundedCorners) {
        selectedIdx = i
      }
    }
    this.getUIContext()?.showTextPickerDialog({
      range: options,
      selected: selectedIdx,
      onAccept: (result: TextPickerResult) => {
        const idx: number = result.index as number
        const config: ConfigManager = ConfigManager.getInstance()
        this.fileRoundedCorners = values[idx]
        config.fileRoundedCorners = values[idx]
      }
    })
  }

  showFolderStyleDialog(): void {
    const options: string[] = [this.getStr($r('app.string.square_option').id), this.getStr($r('app.string.rounded_option').id)]
    const values: number[] = [FOLDER_STYLE_SQUARE, FOLDER_STYLE_ROUNDED_CORNERS]
    let selectedIdx: number = 0
    for (let i: number = 0; i < values.length; i++) {
      if (values[i] === this.folderThumbnailStyle) {
        selectedIdx = i
      }
    }
    this.getUIContext()?.showTextPickerDialog({
      range: options,
      selected: selectedIdx,
      onAccept: (result: TextPickerResult) => {
        const idx: number = result.index as number
        const config: ConfigManager = ConfigManager.getInstance()
        this.folderThumbnailStyle = values[idx]
        config.folderThumbnailStyle = values[idx]
      }
    })
  }

  showFolderMediaCountDialog(): void {
    const options: string[] = [this.getStr($r('app.string.line_option').id), this.getStr($r('app.string.brackets_option').id), this.getStr($r('app.string.none_option').id)]
    const values: number[] = [FOLDER_MEDIA_CNT_LINE, FOLDER_MEDIA_CNT_BRACKETS, FOLDER_MEDIA_CNT_NONE]
    let selectedIdx: number = 0
    for (let i: number = 0; i < values.length; i++) {
      if (values[i] === this.folderMediaCount) {
        selectedIdx = i
      }
    }
    this.getUIContext()?.showTextPickerDialog({
      range: options,
      selected: selectedIdx,
      onAccept: (result: TextPickerResult) => {
        const idx: number = result.index as number
        const config: ConfigManager = ConfigManager.getInstance()
        this.folderMediaCount = values[idx]
        config.folderMediaCount = values[idx]
      }
    })
  }

  showScreenRotationDialog(): void {
    const options: string[] = [this.getStr($r('app.string.system_setting').id), this.getStr($r('app.string.device_rotation').id), this.getStr($r('app.string.aspect_ratio_option').id)]
    const values: number[] = [ROTATE_BY_SYSTEM_SETTING, ROTATE_BY_DEVICE_ROTATION, ROTATE_BY_ASPECT_RATIO]
    let selectedIdx: number = 0
    for (let i: number = 0; i < values.length; i++) {
      if (values[i] === this.screenRotation) {
        selectedIdx = i
      }
    }
    this.getUIContext()?.showTextPickerDialog({
      range: options,
      selected: selectedIdx,
      onAccept: (result: TextPickerResult) => {
        const idx: number = result.index as number
        const config: ConfigManager = ConfigManager.getInstance()
        this.screenRotation = values[idx]
        config.screenRotation = values[idx]
      }
    })
  }

  showFileLoadingPriorityDialog(): void {
    const options: string[] = [this.getStr($r('app.string.speed_option').id), this.getStr($r('app.string.compromise_option').id), this.getStr($r('app.string.validity_option').id)]
    const values: number[] = [PRIORITY_SPEED, PRIORITY_COMPROMISE, PRIORITY_VALIDITY]
    let selectedIdx: number = 0
    for (let i: number = 0; i < values.length; i++) {
      if (values[i] === this.fileLoadingPriority) {
        selectedIdx = i
      }
    }
    this.getUIContext()?.showTextPickerDialog({
      range: options,
      selected: selectedIdx,
      onAccept: (result: TextPickerResult) => {
        const idx: number = result.index as number
        const config: ConfigManager = ConfigManager.getInstance()
        this.fileLoadingPriority = values[idx]
        config.fileLoadingPriority = values[idx]
      }
    })
  }

  // ===========================================================================
  // Export / Import helpers
  // ===========================================================================

  async exportSettingsToFile(): Promise<void> {
    const content: string = SettingsExporter.exportSettings()
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext()!)
      const result: string[] = await documentPicker.save({
        newFileNames: ['gallery-settings.txt']
      })
      if (result.length > 0) {
        const file: fileIo.File = fileIo.openSync(result[0], fileIo.OpenMode.WRITE_ONLY)
        fileIo.writeSync(file.fd, content)
        fileIo.closeSync(file)
        this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.settings_exported_successfully') })
      }
    } catch (e) {
      // user cancelled or error
    }
  }

  async importSettingsFromFile(): Promise<void> {
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext()!)
      const result: string[] = await documentPicker.select({
        fileSuffixFilters: ['.txt']
      })
      if (result.length > 0) {
        const file: fileIo.File = fileIo.openSync(result[0], fileIo.OpenMode.READ_ONLY)
        const stat: fileIo.Stat = fileIo.statSync(result[0])
        const buf: ArrayBuffer = new ArrayBuffer(stat.size)
        fileIo.readSync(file.fd, buf)
        fileIo.closeSync(file)
        const decoder: util.TextDecoder = util.TextDecoder.create('utf-8')
        const content: string = decoder.decodeToString(new Uint8Array(buf))
        SettingsExporter.importSettings(content)
        this.aboutToAppear()
        this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.settings_imported_successfully') })
      }
    } catch (e) {
      // user cancelled or error
    }
  }

  async exportFavoritesToFile(): Promise<void> {
    try {
      const content: string = await FavoritesExporter.exportFavorites()
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext()!)
      const result: string[] = await documentPicker.save({
        newFileNames: ['gallery-favorites.txt']
      })
      if (result.length > 0) {
        const file: fileIo.File = fileIo.openSync(result[0], fileIo.OpenMode.WRITE_ONLY)
        fileIo.writeSync(file.fd, content)
        fileIo.closeSync(file)
        this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.favorites_exported_successfully') })
      }
    } catch (e) {
      // user cancelled or error
    }
  }

  async importFavoritesFromFile(): Promise<void> {
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext()!)
      const result: string[] = await documentPicker.select({
        fileSuffixFilters: ['.txt']
      })
      if (result.length > 0) {
        const file: fileIo.File = fileIo.openSync(result[0], fileIo.OpenMode.READ_ONLY)
        const stat: fileIo.Stat = fileIo.statSync(result[0])
        const buf: ArrayBuffer = new ArrayBuffer(stat.size)
        fileIo.readSync(file.fd, buf)
        fileIo.closeSync(file)
        const decoder: util.TextDecoder = util.TextDecoder.create('utf-8')
        const content: string = decoder.decodeToString(new Uint8Array(buf))
        await FavoritesExporter.importFavorites(content)
        this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.paths_imported_successfully') })
      }
    } catch (e) {
      // user cancelled or error
    }
  }

  // ===========================================================================
  // Build
  // ===========================================================================

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

        Text($r('app.string.settings'))
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

      // Scrollable settings content
      Scroll() {
        Column() {

          // =================================================================
          // GENERAL
          // =================================================================
          this.sectionHeader($r('app.string.general'))

          this.settingToggle($r('app.string.show_hidden_media'), this.showHiddenMedia, (val: boolean) => {
            this.showHiddenMedia = val
            ConfigManager.getInstance().showHiddenMedia = val
          })

          this.settingToggle($r('app.string.show_all_files'), this.showAll, (val: boolean) => {
            this.showAll = val
            ConfigManager.getInstance().showAll = val
          })

          this.settingToggle($r('app.string.delete_empty_folders'), this.deleteEmptyFolders, (val: boolean) => {
            this.deleteEmptyFolders = val
            ConfigManager.getInstance().deleteEmptyFolders = val
          })

          this.settingToggle($r('app.string.search_all_files_by_default'), this.searchAllFilesByDefault, (val: boolean) => {
            this.searchAllFilesByDefault = val
            ConfigManager.getInstance().searchAllFilesByDefault = val
          })

          this.selectorItem($r('app.string.file_loading_priority'), this.getFileLoadingPriorityLabel(), () => {
            this.showFileLoadingPriorityDialog()
          })

          // =================================================================
          // THUMBNAILS
          // =================================================================
          this.sectionHeader($r('app.string.thumbnails'))

          this.settingToggle($r('app.string.crop_thumbnails'), this.cropThumbnails, (val: boolean) => {
            this.cropThumbnails = val
            ConfigManager.getInstance().cropThumbnails = val
          })

          this.settingToggle($r('app.string.show_thumbnail_video_duration'), this.showThumbnailVideoDuration, (val: boolean) => {
            this.showThumbnailVideoDuration = val
            ConfigManager.getInstance().showThumbnailVideoDuration = val
          })

          this.settingToggle($r('app.string.show_thumbnail_file_types'), this.showThumbnailFileTypes, (val: boolean) => {
            this.showThumbnailFileTypes = val
            ConfigManager.getInstance().showThumbnailFileTypes = val
          })

          this.settingToggle($r('app.string.mark_favorite_items'), this.markFavoriteItems, (val: boolean) => {
            this.markFavoriteItems = val
            ConfigManager.getInstance().markFavoriteItems = val
          })

          this.settingToggle($r('app.string.display_file_names'), this.displayFileNames, (val: boolean) => {
            this.displayFileNames = val
            ConfigManager.getInstance().displayFileNames = val
          })

          this.settingToggle($r('app.string.limit_folder_title'), this.limitFolderTitle, (val: boolean) => {
            this.limitFolderTitle = val
            ConfigManager.getInstance().limitFolderTitle = val
          })

          this.selectorItem($r('app.string.file_rounded_corners'), this.getRoundedCornersLabel(), () => {
            this.showRoundedCornersDialog()
          })

          this.selectorItem($r('app.string.folder_style'), this.getFolderStyleLabel(), () => {
            this.showFolderStyleDialog()
          })

          this.selectorItem($r('app.string.folder_media_count'), this.getFolderMediaCountLabel(), () => {
            this.showFolderMediaCountDialog()
          })

          this.sliderItem($r('app.string.thumbnail_spacing'), this.thumbnailSpacing, 0, 10, 1, (val: number) => {
            this.thumbnailSpacing = val
            ConfigManager.getInstance().thumbnailSpacing = val
          })

          // =================================================================
          // DISPLAY
          // =================================================================
          this.sectionHeader($r('app.string.display'))

          this.settingToggle($r('app.string.show_extended_details'), this.showExtendedDetails, (val: boolean) => {
            this.showExtendedDetails = val
            ConfigManager.getInstance().showExtendedDetails = val
          })

          if (this.showExtendedDetails) {
            this.settingToggle($r('app.string.hide_extended_details'), this.hideExtendedDetails, (val: boolean) => {
              this.hideExtendedDetails = val
              ConfigManager.getInstance().hideExtendedDetails = val
            })
          }

          // =================================================================
          // VIDEOS
          // =================================================================
          this.sectionHeader($r('app.string.videos_section'))

          this.settingToggle($r('app.string.autoplay_videos'), this.autoplayVideos, (val: boolean) => {
            this.autoplayVideos = val
            ConfigManager.getInstance().autoplayVideos = val
          })

          this.settingToggle($r('app.string.loop_videos'), this.loopVideos, (val: boolean) => {
            this.loopVideos = val
            ConfigManager.getInstance().loopVideos = val
          })

          this.settingToggle($r('app.string.open_videos_on_separate_screen'), this.openVideosOnSeparateScreen, (val: boolean) => {
            this.openVideosOnSeparateScreen = val
            ConfigManager.getInstance().openVideosOnSeparateScreen = val
          })

          this.settingToggle($r('app.string.remember_last_video_position'), this.rememberLastVideoPosition, (val: boolean) => {
            this.rememberLastVideoPosition = val
            ConfigManager.getInstance().rememberLastVideoPosition = val
          })

          this.settingToggle($r('app.string.animate_gifs'), this.animateGifs, (val: boolean) => {
            this.animateGifs = val
            ConfigManager.getInstance().animateGifs = val
          })

          // =================================================================
          // FULLSCREEN MEDIA
          // =================================================================
          this.sectionHeader($r('app.string.fullscreen_media'))

          this.settingToggle($r('app.string.max_brightness'), this.maxBrightness, (val: boolean) => {
            this.maxBrightness = val
            ConfigManager.getInstance().maxBrightness = val
          })

          this.settingToggle($r('app.string.black_background'), this.blackBackground, (val: boolean) => {
            this.blackBackground = val
            ConfigManager.getInstance().blackBackground = val
          })

          this.settingToggle($r('app.string.hide_system_ui'), this.hideSystemUI, (val: boolean) => {
            this.hideSystemUI = val
            ConfigManager.getInstance().hideSystemUI = val
          })

          this.settingToggle($r('app.string.show_notch'), this.showNotch, (val: boolean) => {
            this.showNotch = val
            ConfigManager.getInstance().showNotch = val
          })

          this.settingToggle($r('app.string.allow_photo_gestures'), this.allowPhotoGestures, (val: boolean) => {
            this.allowPhotoGestures = val
            ConfigManager.getInstance().allowPhotoGestures = val
          })

          this.settingToggle($r('app.string.allow_video_gestures'), this.allowVideoGestures, (val: boolean) => {
            this.allowVideoGestures = val
            ConfigManager.getInstance().allowVideoGestures = val
          })

          this.settingToggle($r('app.string.allow_down_gesture'), this.allowDownGesture, (val: boolean) => {
            this.allowDownGesture = val
            ConfigManager.getInstance().allowDownGesture = val
          })

          this.settingToggle($r('app.string.allow_instant_change'), this.allowInstantChange, (val: boolean) => {
            this.allowInstantChange = val
            ConfigManager.getInstance().allowInstantChange = val
          })

          this.selectorItem($r('app.string.screen_rotation'), this.getScreenRotationLabel(), () => {
            this.showScreenRotationDialog()
          })

          // =================================================================
          // DEEP ZOOMABLE IMAGES
          // =================================================================
          this.sectionHeader($r('app.string.deep_zoomable_images'))

          this.settingToggle($r('app.string.allow_zooming_images'), this.allowZoomingImages, (val: boolean) => {
            this.allowZoomingImages = val
            ConfigManager.getInstance().allowZoomingImages = val
          })

          if (this.allowZoomingImages) {
            this.settingToggle($r('app.string.show_highest_quality'), this.showHighestQuality, (val: boolean) => {
              this.showHighestQuality = val
              ConfigManager.getInstance().showHighestQuality = val
            })

            this.settingToggle($r('app.string.allow_one_to_one_zoom'), this.allowOneToOneZoom, (val: boolean) => {
              this.allowOneToOneZoom = val
              ConfigManager.getInstance().allowOneToOneZoom = val
            })

            this.settingToggle($r('app.string.allow_rotating_with_gestures'), this.allowRotatingWithGestures, (val: boolean) => {
              this.allowRotatingWithGestures = val
              ConfigManager.getInstance().allowRotatingWithGestures = val
            })
          }

          // =================================================================
          // BOTTOM ACTIONS
          // =================================================================
          this.sectionHeader($r('app.string.bottom_actions'))

          this.settingToggle($r('app.string.show_bottom_actions'), this.bottomActions, (val: boolean) => {
            this.bottomActions = val
            ConfigManager.getInstance().bottomActions = val
          })

          // =================================================================
          // RECYCLE BIN
          // =================================================================
          this.sectionHeader($r('app.string.recycle_bin'))

          this.settingToggle($r('app.string.use_recycle_bin'), this.useRecycleBin, (val: boolean) => {
            this.useRecycleBin = val
            ConfigManager.getInstance().useRecycleBin = val
          })

          if (this.useRecycleBin) {
            this.settingToggle($r('app.string.show_recycle_bin_in_folders'), this.showRecycleBinAtFolders, (val: boolean) => {
              this.showRecycleBinAtFolders = val
              ConfigManager.getInstance().showRecycleBinAtFolders = val
            })

            this.settingToggle($r('app.string.show_recycle_bin_last'), this.showRecycleBinLast, (val: boolean) => {
              this.showRecycleBinLast = val
              ConfigManager.getInstance().showRecycleBinLast = val
            })
          }

          // =================================================================
          // FOLDER MANAGEMENT
          // =================================================================
          this.sectionHeader($r('app.string.folder_management'))

          Row() {
            Text($r('app.string.manage_included_folders'))
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/IncludedFoldersPage' })
          })

          Row() {
            Text($r('app.string.manage_excluded_folders'))
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/ExcludedFoldersPage' })
          })

          Row() {
            Text($r('app.string.manage_hidden_folders'))
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/HiddenFoldersPage' })
          })

          // =================================================================
          // TRANSFER
          // =================================================================
          this.sectionHeader($r('app.string.transfer'))

          Row() {
            Text($r('app.string.export_settings'))
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.exportSettingsToFile()
          })

          Row() {
            Text($r('app.string.import_settings'))
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.importSettingsFromFile()
          })

          Row() {
            Text($r('app.string.export_favorite_paths'))
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.exportFavoritesToFile()
          })

          Row() {
            Text($r('app.string.import_favorite_paths'))
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.importFavoritesFromFile()
          })

          // =================================================================
          // STORAGE (T-058)
          // =================================================================
          this.sectionHeader($r('app.string.storage_section'))

          Row() {
            Column() {
              Text($r('app.string.clear_cache'))
                .fontSize(16)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
              Text(this.cacheSize)
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Button($r('app.string.clear'))
              .fontSize(14)
              .height(36)
              .onClick(() => {
                this.clearCache()
              })
          }
          .width('100%')
          .height(64)
          .padding({ left: 16, right: 16 })

          // =================================================================
          // ABOUT (T-060)
          // =================================================================
          this.sectionHeader($r('app.string.other_section'))

          Row() {
            Text($r('app.string.about'))
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/AboutPage' })
          })

          // 沙箱测试入口 (开发调试用)
          Row() {
            Text('🔬 沙箱机制测试')
              .fontSize(16)
              .fontColor('#FF6600')
              .layoutWeight(1)

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/SandboxTestPage' })
          })

          // Bottom padding
          Row()
            .height(32)
            .width('100%')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}

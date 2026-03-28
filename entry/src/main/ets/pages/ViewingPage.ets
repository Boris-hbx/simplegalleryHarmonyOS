// =============================================================================
// ViewingPage.ets — Swiper-based media pager for full-screen viewing (T-021)
// FR-013: Left/right swipe navigation
// FR-014: Pinch-zoom vs swipe conflict resolution
// FR-015: Instant-change touch zones (left/right 1/7)
// FR-019: Fullscreen mode toggle
// FR-021: Down-swipe-to-close gesture
// =============================================================================

import { router } from '@kit.ArkUI'
import { window } from '@kit.ArkUI'
import { display } from '@kit.ArkUI'
import { Medium } from '../common/models/Medium'
import { PhotoViewer } from '../components/PhotoViewer'
import { VideoViewer } from '../components/VideoViewer'

import { fileIo, fileUri } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { ConfigManager } from '../datastore/ConfigManager'
import {
  TYPE_VIDEOS,
  TYPE_GIFS,
  SLIDESHOW_ANIMATION_FADE,
  SLIDESHOW_ANIMATION_SLIDE,
  SLIDESHOW_FADE_DURATION,
  BOTTOM_ACTION_TOGGLE_FAVORITE,
  BOTTOM_ACTION_EDIT,
  BOTTOM_ACTION_SHARE,
  BOTTOM_ACTION_DELETE
} from '../common/constants/Constants'
import { FileOperations } from '../utils/FileOperations'
import { ShareUtils } from '../utils/ShareUtils'
import { DeleteConfirmDialog } from '../components/FileOpDialogs'
import { common, Want, wantConstant } from '@kit.AbilityKit'

interface EditNavParams {
  path: string
}

// T-037: Menu item interface for bindMenu
interface ViewingMenuItem {
  value: string
  action: () => void
}

// Animation duration for fullscreen toggle fade
const FULLSCREEN_ANIM_DURATION: number = 200

// Scale threshold above which swipe is disabled (FR-014)
const ZOOM_DISABLE_THRESHOLD: number = 1.05

// Slideshow auto-hide delay for title bar (ms)
const SLIDESHOW_UI_HIDE_DELAY: number = 2000

// Brightness/volume indicator display duration (ms)
const INDICATOR_HIDE_DELAY: number = 800

@Entry
@Component
struct ViewingPage {
  @State mediaList: Medium[] = []
  @State currentIndex: number = 0
  @State currentMedium: Medium = new Medium()
  @State isFullscreen: boolean = false
  @State swiperDisabled: boolean = false
  @State uiOpacity: number = 1

  // T-024 Slideshow state
  @State isSlideshowActive: boolean = false
  @State slideshowTimerId: number = -1
  private slideshowUiTimerId: number = -1

  // T-025 EXIF panel state
  @State showExifPanel: boolean = false

  // T-054 Bottom actions state
  @State showBottomActions: boolean = true
  @State visibleActions: number = BOTTOM_ACTION_TOGGLE_FAVORITE | BOTTOM_ACTION_EDIT | BOTTOM_ACTION_SHARE | BOTTOM_ACTION_DELETE
  @State isFavorite: boolean = false

  // T-025 Brightness/Volume gesture state
  @State brightnessLevel: number = 0.5
  @State volumeLevel: number = 0.5
  @State showBrightnessIndicator: boolean = false
  @State showVolumeIndicator: boolean = false
  private indicatorTimerId: number = -1

  private deleteConfirmDialogController: CustomDialogController = new CustomDialogController({
    builder: DeleteConfirmDialog({
      fileCount: 1,
      onConfirm: (skipRecycleBin: boolean) => {
        this.executeDeleteCurrentMedia(skipRecycleBin)
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  private swiperController: SwiperController = new SwiperController()
  private childScale: number = 1.0

  private getStr(resId: number): string {
    try {
      return getContext(this).resourceManager.getStringSync(resId)
    } catch (e) {
      return ''
    }
  }

  aboutToAppear(): void {
    const params: Record<string, Object> = router.getParams() as Record<string, Object>
    if (params !== null && params !== undefined) {
      // Media list passed as JSON string (complex objects cannot be passed directly)
      const mediaJson: string = (params['mediaListJson'] as string) || '[]'
      try {
        const parsed: Object[] = JSON.parse(mediaJson) as Object[]
        const tempList: Medium[] = []
        for (let i: number = 0; i < parsed.length; i++) {
          const item: Record<string, Object> = parsed[i] as Record<string, Object>
          const m: Medium = new Medium(
            (item['id'] as number) || 0,
            (item['name'] as string) || '',
            (item['path'] as string) || '',
            (item['parentPath'] as string) || '',
            (item['modified'] as number) || 0,
            (item['taken'] as number) || 0,
            (item['size'] as number) || 0,
            (item['type'] as number) || 0,
            (item['videoDuration'] as number) || 0,
            (item['isFavorite'] as boolean) || false,
            (item['deletedTS'] as number) || 0,
            (item['mediaStoreId'] as number) || 0
          )
          tempList.push(m)
        }
        this.mediaList = tempList
      } catch (e) {
        console.error('[ViewingPage] Failed to parse media list')
      }
      this.currentIndex = (params['selectedIndex'] as number) || 0
    }
    this.updateCurrentMedium()

    // Apply initial system UI config
    try {
      const config: ConfigManager = ConfigManager.getInstance()
      if (config.hideSystemUI) {
        this.setFullscreen(true)
      }
      // T-024: Auto-start slideshow if configured
      if (config.slideshowStartOnEnter) {
        this.startSlideshow()
      }
      // T-025: Read initial brightness from window
      this.initBrightness()
      // T-054: Read bottom actions config
      this.showBottomActions = config.bottomActions
      this.visibleActions = config.visibleBottomActions
    } catch (e) {
      // ConfigManager may not be ready
    }
  }

  aboutToDisappear(): void {
    this.stopSlideshow()
    if (this.indicatorTimerId !== -1) {
      clearTimeout(this.indicatorTimerId)
      this.indicatorTimerId = -1
    }
    // Restore window layout if fullscreen was set
    if (this.isFullscreen) {
      try {
        window.getLastWindow(this.getUIContext().getHostContext()!).then((windowClass: window.Window): void => {
          windowClass.setWindowLayoutFullScreen(false)
        })
      } catch (e) {
        // Context may not be available during teardown
      }
    }
  }

  build() {
    Stack() {
      // Swiper media pager — fills entire screen
      Swiper(this.swiperController) {
        ForEach(this.mediaList, (medium: Medium): void => {
          if (medium.type === TYPE_VIDEOS) {
            VideoViewer({ medium: medium })
          } else {
            PhotoViewer({
              medium: medium,
              onScaleChange: (scale: number): void => {
                this.childScale = scale
                this.swiperDisabled = scale > ZOOM_DISABLE_THRESHOLD
              },
              onSingleTap: (): void => {
                this.toggleFullscreen()
              }
            })
          }
        }, (medium: Medium, _index: number): string => {
          // BUG-027: Use only path as key, not index. Including index causes all
          // keys to change after deletion (subsequent indices shift), making ArkUI
          // destroy/recreate all Swiper children and reset to index 0.
          return medium.path
        })
      }
      .index(this.currentIndex)
      .disableSwipe(this.swiperDisabled)
      .indicator(false)
      .loop(false)
      .cachedCount(1)
      .itemSpace(0)
      .onChange((index: number): void => {
        this.currentIndex = index
        // PAT-011b: Replace entire currentMedium object to trigger re-render
        this.updateCurrentMedium()
      })
      .width('100%')
      .height('100%')

      // FR-015/FR-019: Instant-change touch zones and fullscreen toggle
      // handled via onTouch on root Stack (see below) instead of overlay Row,
      // so pinch-zoom and double-tap gestures pass through to PhotoViewer.

      // BUG-025: Title bar overlay (top) — conditionally rendered based on
      // fullscreen state. Previously used opacity to hide, but the Text components
      // (file name, position indicator) were still rendered and could overlap the
      // image content in some layouts. Now fully removed from render tree when hidden.
      if (this.uiOpacity > 0) {
        Column() {
          Row() {
            Image($r('sys.media.ohos_ic_back'))
              .width(24)
              .height(24)
              .fillColor($r('sys.color.ohos_id_color_text_primary_contrary'))
              .onClick((): void => {
                router.back()
              })

            Text(this.currentMedium.name)
              .fontSize(18)
              .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
              .margin({ left: 16 })
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            // Position indicator
            if (this.mediaList.length > 1) {
              Text((this.currentIndex + 1).toString() + '/' + this.mediaList.length.toString())
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
                .margin({ right: 8 })
            }

            // T-037: Overflow menu (Set as wallpaper, Edit, Slideshow, Details)
            Image($r('sys.media.ohos_ic_public_more'))
              .width(24)
              .height(24)
              .fillColor($r('sys.color.ohos_id_color_text_primary_contrary'))
              .margin({ right: 16 })
              .bindMenu(this.buildViewingMenuItems())
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .linearGradient({
            angle: 0,
            colors: [['rgba(0,0,0,0.6)', 0.0], ['rgba(0,0,0,0)', 1.0]]
          })
        }
        .width('100%')
        .opacity(this.uiOpacity)
        .alignItems(HorizontalAlign.Start)
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // T-025: Brightness/Volume gesture zones
      Row() {
        // Left 15% — brightness gesture zone
        Column()
          .width('15%')
          .height('100%')
          .gesture(
            PanGesture({ direction: PanDirection.Vertical })
              .onActionUpdate((event: GestureEvent): void => {
                this.onBrightnessGesture(event)
              })
          )
          .hitTestBehavior(HitTestMode.Transparent)

        // Center gap
        Column()
          .width('70%')
          .height('100%')
          .hitTestBehavior(HitTestMode.None)

        // Right 15% — volume gesture zone
        Column()
          .width('15%')
          .height('100%')
          .gesture(
            PanGesture({ direction: PanDirection.Vertical })
              .onActionUpdate((event: GestureEvent): void => {
                this.onVolumeGesture(event)
              })
          )
          .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)

      // T-025: Brightness indicator overlay
      if (this.showBrightnessIndicator) {
        Column() {
          Text($r('app.string.brightness'))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
          Progress({ value: Math.round(this.brightnessLevel * 100), total: 100, type: ProgressType.Linear })
            .width(120)
            .height(4)
            .margin({ top: 4 })
          Text(Math.round(this.brightnessLevel * 100).toString() + '%')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
            .margin({ top: 2 })
        }
        .position({ x: '5%', y: '40%' })
        .padding(12)
        .borderRadius(8)
        .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
        .opacity(0.85)
      }

      // T-025: Volume indicator overlay
      if (this.showVolumeIndicator) {
        Column() {
          Text($r('app.string.volume'))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
          Progress({ value: Math.round(this.volumeLevel * 100), total: 100, type: ProgressType.Linear })
            .width(120)
            .height(4)
            .margin({ top: 4 })
          Text(Math.round(this.volumeLevel * 100).toString() + '%')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary_contrary'))
            .margin({ top: 2 })
        }
        .position({ x: '75%', y: '40%' })
        .padding(12)
        .borderRadius(8)
        .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
        .opacity(0.85)
      }

      // T-054: Bottom actions bar
      // BUG-025: Use Column with Blank() spacer to push bar to bottom instead of
      // position/translate which caused overlap with image content
      // Round6-Fix5: Hide bottom actions for videos to avoid overlapping VideoViewer's progress bar
      if (!this.isFullscreen && this.showBottomActions && this.currentMedium.type !== TYPE_VIDEOS) {
        Column() {
          Blank()
          Row() {
            if ((this.visibleActions & BOTTOM_ACTION_TOGGLE_FAVORITE) !== 0) {
              Column() {
                Image(this.isFavorite ? $r('app.media.ic_star_filled') : $r('app.media.ic_star_outline'))
                  .width(24)
                  .height(24)
                  .fillColor(this.isFavorite ? '#FFD700' : '#FFFFFF')
              }
              .onClick((): void => {
                this.toggleFavorite()
              })
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .height('100%')
            }

            if ((this.visibleActions & BOTTOM_ACTION_EDIT) !== 0 && !this.currentMedium.isVideo()) {
              Column() {
                Image($r('app.media.ic_edit'))
                  .width(24)
                  .height(24)
                  .fillColor('#FFFFFF')
              }
              .onClick((): void => {
                this.navigateToEdit()
              })
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .height('100%')
            }

            if ((this.visibleActions & BOTTOM_ACTION_SHARE) !== 0) {
              Column() {
                Image($r('app.media.ic_share'))
                  .width(24)
                  .height(24)
                  .fillColor('#FFFFFF')
              }
              .onClick((): void => {
                this.shareCurrentMedia()
              })
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .height('100%')
            }

            if ((this.visibleActions & BOTTOM_ACTION_DELETE) !== 0) {
              Column() {
                Image($r('app.media.ic_delete'))
                  .width(24)
                  .height(24)
                  .fillColor('#FFFFFF')
              }
              .onClick((): void => {
                // BUG-039 G-005: createDeleteRequest in FileOperations provides system confirmation
                this.executeDeleteCurrentMedia(false)
              })
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .height('100%')
            }
          }
          .width('100%')
          .height(56)
          .backgroundColor('#CC000000')
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // T-025: EXIF details panel placeholder (dialog triggered via onExifChange)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    // Note: Removed onTouch handler that was intercepting touch events and
    // conflicting with PhotoViewer's double-tap and pinch gestures (BUG-026).
    // Fullscreen toggle is now handled by PhotoViewer via single-tap callback.
    // Instant-change (tap left/right edges) deferred — gesture conflict too severe.
    .gesture(
      SwipeGesture({ direction: SwipeDirection.Vertical })
        .onAction((event: GestureEvent): void => {
          this.onDownSwipe(event)
        })
    )
  }

  // ---------------------------------------------------------------------------
  // T-037: Viewing page menu items
  // ---------------------------------------------------------------------------

  // RITUAL-005 方案B + BUG-041f: Copy to sandbox then open with viewData
  // (photoAccessHelper URI not readable by other apps — PIT-053)
  private openInSystemGallery(): void {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const mediaUri: string = this.currentMedium.path
      const fileName: string = this.currentMedium.name || 'image.jpg'

      // Copy to sandbox (PIT-053)
      const srcFile: fileIo.File = fileIo.openSync(mediaUri, fileIo.OpenMode.READ_ONLY)
      const openDir: string = ctx.cacheDir + '/open_temp'
      try { fileIo.mkdirSync(openDir, true) } catch (e) { /* exists */ }
      const destPath: string = openDir + '/' + fileName
      const destFile: fileIo.File = fileIo.openSync(destPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      fileIo.copyFileSync(srcFile.fd, destFile.fd)
      fileIo.closeSync(srcFile)
      fileIo.closeSync(destFile)

      const sandboxUri: string = fileUri.getUriFromPath(destPath)
      // Try system Photos app first, then fallback to implicit intent
      const want: Want = {
        bundleName: 'com.huawei.hmos.photos',
        action: 'ohos.want.action.viewData',
        uri: sandboxUri,
        type: 'image/*',
        flags: 0x00000001
      }
      ctx.startAbility(want).then((): void => {
        console.info('[ViewingPage] openInSystemGallery succeeded (Photos app)')
      }).catch((err: Error): void => {
        // Fallback: implicit intent without bundleName
        const fallbackWant: Want = {
          action: 'ohos.want.action.viewData',
          uri: sandboxUri,
          type: 'image/*',
          flags: 0x00000001
        }
        ctx.startAbility(fallbackWant).catch((): void => {
          this.getUIContext()?.getPromptAction()?.showToast({ message: '无法打开系统图库' })
        })
        this.getUIContext()?.getPromptAction()?.showToast({ message: '无法打开系统图库' })
      })
    } catch (e) {
      this.getUIContext()?.getPromptAction()?.showToast({ message: '无法打开系统图库' })
    }
  }

  // T-071 ⑥ + BUG-040 TC-22: Rotate image and save to sandbox, then refresh display
  private async rotateCurrentImage(degrees: number): Promise<void> {
    try {
      const mediaUri: string = this.currentMedium.path
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const srcFile: fileIo.File = fileIo.openSync(mediaUri, fileIo.OpenMode.READ_ONLY)
      const imgSource: image.ImageSource = image.createImageSource(srcFile.fd)
      const pixelMap: image.PixelMap = await imgSource.createPixelMap()
      await pixelMap.rotate(degrees)

      // Pack rotated image to sandbox
      const packer: image.ImagePacker = image.createImagePacker()
      const packOpt: image.PackingOption = { format: 'image/jpeg', quality: 95 }
      const buf: ArrayBuffer = await packer.packToData(pixelMap, packOpt)

      const rotateDir: string = ctx.cacheDir + '/rotate_temp'
      try { fileIo.mkdirSync(rotateDir, true) } catch (mkErr) { /* exists */ }
      const rotatePath: string = rotateDir + '/rotated_' + Date.now().toString() + '.jpg'
      const destFile: fileIo.File = fileIo.openSync(rotatePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(destFile.fd, buf)
      fileIo.closeSync(destFile)

      packer.release()
      pixelMap.release()
      imgSource.release()
      fileIo.closeSync(srcFile)

      // Update current medium's path to the rotated sandbox file → triggers PhotoViewer refresh
      const rotatedUri: string = fileUri.getUriFromPath(rotatePath)
      const oldMedium: Medium = this.currentMedium
      const rotatedMedium: Medium = new Medium(
        oldMedium.id, oldMedium.name, rotatedUri, oldMedium.parentPath,
        oldMedium.modified, oldMedium.taken, oldMedium.size, oldMedium.type,
        oldMedium.videoDuration, oldMedium.isFavorite, oldMedium.deletedTS, oldMedium.mediaStoreId
      )
      // Replace in mediaList and trigger re-render
      const newList: Medium[] = []
      for (let i: number = 0; i < this.mediaList.length; i++) {
        if (i === this.currentIndex) {
          newList.push(rotatedMedium)
        } else {
          newList.push(this.mediaList[i])
        }
      }
      this.mediaList = newList
      this.currentMedium = rotatedMedium

      this.getUIContext()?.getPromptAction()?.showToast({ message: '已旋转 ' + degrees.toString() + '°（仅当前预览，系统媒体库为只读）' })
    } catch (e) {
      this.getUIContext()?.getPromptAction()?.showToast({ message: '旋转失败' })
    }
  }

  // T-071 ④: Hide current file's folder by creating .nomedia
  private hideCurrentFile(): void {
    try {
      const parentPath: string = this.currentMedium.parentPath
      if (parentPath.length > 0 && !parentPath.startsWith('file://media')) {
        const nomediaPath: string = parentPath + '/.nomedia'
        const file: fileIo.File = fileIo.openSync(nomediaPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
        fileIo.closeSync(file)
        this.getUIContext()?.getPromptAction()?.showToast({ message: '文件夹已隐藏' })
      } else {
        this.getUIContext()?.getPromptAction()?.showToast({ message: '系统媒体库文件不支持隐藏' })
      }
    } catch (e) {
      this.getUIContext()?.getPromptAction()?.showToast({ message: '隐藏失败' })
    }
  }

  // T-071 ⑤: Save current image to a user-chosen location
  private async saveCurrentImageAs(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const mediaUri: string = this.currentMedium.path
      const fileName: string = this.currentMedium.name

      // BUG-041d: Save directly to app's filesDir (Download not accessible without permission)
      const srcFile: fileIo.File = fileIo.openSync(mediaUri, fileIo.OpenMode.READ_ONLY)
      const saveDir: string = ctx.filesDir + '/saved'
      try { fileIo.mkdirSync(saveDir, true) } catch (e) { /* exists */ }
      const savePath: string = saveDir + '/' + fileName
      const destFile: fileIo.File = fileIo.openSync(savePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      fileIo.copyFileSync(srcFile.fd, destFile.fd)
      fileIo.closeSync(srcFile)
      fileIo.closeSync(destFile)
      this.getUIContext()?.getPromptAction()?.showToast({ message: '已保存到：' + savePath })
    } catch (e) {
      this.getUIContext()?.getPromptAction()?.showToast({ message: '另存为失败' })
    }
  }

  // PIT-066: wallpaper API is System-only. Copy to sandbox then open in system gallery.
  // PIT-053: photoAccessHelper URI must be copied to sandbox for other apps to access.
  private async launchSystemWallpaper(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const mediaUri: string = this.currentMedium.path

      // Step 1: Copy image from photoAccessHelper URI to sandbox
      const srcFile: fileIo.File = fileIo.openSync(mediaUri, fileIo.OpenMode.READ_ONLY)
      const tempDir: string = ctx.cacheDir + '/wallpaper_temp'
      try {
        fileIo.mkdirSync(tempDir, true)
      } catch (_e) {
        // Directory may already exist
      }
      const fileName: string = this.currentMedium.name || ('wallpaper_' + Date.now().toString() + '.jpg')
      const destPath: string = tempDir + '/' + fileName
      const destFile: fileIo.File = fileIo.openSync(
        destPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      )
      fileIo.copyFileSync(srcFile.fd, destFile.fd)
      fileIo.closeSync(srcFile)
      fileIo.closeSync(destFile)

      // Step 2: Convert sandbox path to file:// URI
      const shareableUri: string = fileUri.getUriFromPath(destPath)
      console.info('[Wallpaper] shareableUri: ' + shareableUri)

      // Step 3: Open directly in HarmonyOS system gallery (Photos app)
      const want: Want = {
        bundleName: 'com.huawei.photos',
        action: 'ohos.want.action.viewData',
        uri: shareableUri,
        type: 'image/*',
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      }
      await ctx.startAbility(want)
    } catch (e) {
      console.error('[Wallpaper] Failed to open in system gallery: ' + (e as Error).message)
      this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.failed_to_set_wallpaper') })
    }
  }

  private async launchSystemEditor(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const isVideo: boolean = this.currentMedium.isVideo()
      const mediaType: string = isVideo ? 'video/*' : 'image/*'

      const want: Want = {
        action: 'ohos.want.action.editData',
        uri: this.currentMedium.path,
        type: mediaType
      }
      console.info('[Editor] Launching system editor for: ' + this.currentMedium.path + ' type=' + mediaType)
      await ctx.startAbility(want)
    } catch (e) {
      console.error('[Editor] Failed to launch system editor: ' + (e as Error).message)
      // Fallback: navigate to built-in editor for images only
      if (!this.currentMedium.isVideo()) {
        const editParams: EditNavParams = { path: this.currentMedium.path }
        router.pushUrl({ url: 'pages/EditPage', params: editParams })
      } else {
        this.getUIContext()?.getPromptAction()?.showToast({ message: '无法打开系统编辑器' })
      }
    }
  }

  private async showDetailsDialog(): Promise<void> {
    const m: Medium = this.currentMedium
    const lines: string[] = []

    // Filename
    lines.push(m.name)
    // Date taken or modified
    if (m.taken > 0) {
      lines.push(this.formatTimestamp(m.taken))
    } else if (m.modified > 0) {
      lines.push(this.formatTimestamp(m.modified))
    }
    lines.push('')  // blank line separator

    // Try to read EXIF and file stats
    try {
      const file: fileIo.File = fileIo.openSync(m.path, fileIo.OpenMode.READ_ONLY)
      try {
        const stat: fileIo.Stat = fileIo.statSync(file.fd)
        const fileSize: number = stat.size > 0 ? stat.size : m.size

        if (!m.isVideo()) {
          // Read image EXIF
          const imgSource: image.ImageSource = image.createImageSource(file.fd)
          const imgInfo: image.ImageInfo = await imgSource.getImageInfo()
          const w: number = imgInfo.size.width
          const h: number = imgInfo.size.height

          // Resolution + size + format
          const ext: string = m.name.substring(m.name.lastIndexOf('.') + 1).toUpperCase()
          lines.push(w.toString() + ' × ' + h.toString() + '    ' + this.formatFileSize(fileSize) + '    ' + ext)

          // EXIF properties
          const exifLines: string[] = []
          try {
            const model: string = await imgSource.getImageProperty(image.PropertyKey.MODEL)
            if (model.length > 0 && model !== 'unknown') exifLines.push(this.detailLine('设备', model))
          } catch (e) { /* skip */ }
          try {
            const iso: string = await imgSource.getImageProperty(image.PropertyKey.ISO_SPEED_RATINGS)
            if (iso.length > 0 && iso !== 'unknown') exifLines.push(this.detailLine('ISO', iso))
          } catch (e) { /* skip */ }
          try {
            const exposure: string = await imgSource.getImageProperty(image.PropertyKey.EXPOSURE_TIME)
            if (exposure.length > 0 && exposure !== 'unknown') exifLines.push(this.detailLine('快门', exposure + 's'))
          } catch (e) { /* skip */ }
          try {
            const fNum: string = await imgSource.getImageProperty(image.PropertyKey.F_NUMBER)
            if (fNum.length > 0 && fNum !== 'unknown') exifLines.push(this.detailLine('光圈', 'f/' + fNum))
          } catch (e) { /* skip */ }
          try {
            const focal: string = await imgSource.getImageProperty(image.PropertyKey.FOCAL_LENGTH)
            if (focal.length > 0 && focal !== 'unknown') exifLines.push(this.detailLine('焦距', focal + 'mm'))
          } catch (e) { /* skip */ }

          if (exifLines.length > 0) {
            lines.push('')
            for (const line of exifLines) {
              lines.push(line)
            }
          }

          imgSource.release()
        } else {
          // Video: resolution + size + format + duration
          const ext: string = m.name.substring(m.name.lastIndexOf('.') + 1).toUpperCase()
          lines.push(this.formatFileSize(fileSize) + '    ' + ext)
          if (m.videoDuration > 0) {
            const sec: number = Math.floor(m.videoDuration / 1000)
            const mm: string = Math.floor(sec / 60).toString().padStart(2, '0')
            const ss: string = (sec % 60).toString().padStart(2, '0')
            lines.push(this.detailLine('时长', mm + ':' + ss))
          }
        }
      } finally {
        fileIo.closeSync(file)
      }
    } catch (e) {
      // Fallback: basic info only
      if (m.size > 0) {
        lines.push(this.detailLine('大小', this.formatFileSize(m.size)))
      }
      lines.push(this.detailLine('类型', m.isVideo() ? '视频' : '图片'))
    }

    // Path
    lines.push('')
    lines.push(this.detailLine('路径', m.path))

    this.getUIContext()?.getPromptAction()?.showDialog({
      title: '详情',
      message: lines.join('\n'),
      buttons: [{ text: '关闭', color: '#007DFF' }]
    })
    this.showExifPanel = false
  }

  private detailLine(label: string, value: string): string {
    return label + '：' + value
  }

  private formatFileSize(bytes: number): string {
    if (bytes < 1024) return bytes.toString() + ' B'
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB'
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + ' MB'
    return (bytes / 1073741824).toFixed(1) + ' GB'
  }

  private formatTimestamp(ts: number): string {
    const d: Date = new Date(ts)
    const y: number = d.getFullYear()
    const mo: string = (d.getMonth() + 1).toString().padStart(2, '0')
    const day: string = d.getDate().toString().padStart(2, '0')
    const h: string = d.getHours().toString().padStart(2, '0')
    const mi: string = d.getMinutes().toString().padStart(2, '0')
    return y.toString() + '/' + mo + '/' + day + ' ' + h + ':' + mi
  }

  private buildViewingMenuItems(): Array<ViewingMenuItem> {
    const items: Array<ViewingMenuItem> = []

    // Wallpaper feature removed — Boris裁决：第三方App无法设壁纸，去掉此入口

    // Edit — launch system editor (supports both image and video)
    items.push({
      value: this.getStr($r('app.string.edit').id),
      action: (): void => {
        this.launchSystemEditor()
      }
    })

    // T-024: Slideshow toggle
    items.push({
      value: this.isSlideshowActive
        ? this.getStr($r('app.string.stop_slideshow').id)
        : this.getStr($r('app.string.slideshow').id),
      action: (): void => {
        if (this.isSlideshowActive) {
          this.stopSlideshow()
        } else {
          this.startSlideshow()
        }
      }
    })

    // T-071 ②: Open with — open in another app via viewData action
    items.push({
      value: '打开方式',
      action: (): void => {
        this.openInSystemGallery()
      }
    })

    // T-071 ⑥: Rotate — image only
    if (!this.currentMedium.isVideo()) {
      items.push({
        value: '旋转 90°',
        action: (): void => {
          this.rotateCurrentImage(90)
        }
      })
    }

    // T-071 ④: Hide/unhide — toggle .nomedia in parent folder
    items.push({
      value: '隐藏',
      action: (): void => {
        this.hideCurrentFile()
      }
    })

    // T-071 ⑤: Save as — image only, copy to user-chosen location
    if (!this.currentMedium.isVideo()) {
      items.push({
        value: '另存为',
        action: (): void => {
          this.saveCurrentImageAs()
        }
      })
    }

    // Details — show as dialog (like Android PropertiesDialog)
    items.push({
      value: this.getStr($r('app.string.details').id),
      action: (): void => {
        this.showDetailsDialog()
      }
    })

    return items
  }

  // ---------------------------------------------------------------------------
  // State updates
  // ---------------------------------------------------------------------------

  private updateCurrentMedium(): void {
    if (this.currentIndex >= 0 && this.currentIndex < this.mediaList.length) {
      // PAT-011b: Full object replacement to trigger @State re-render
      this.currentMedium = this.mediaList[this.currentIndex]
      this.isFavorite = this.currentMedium.isFavorite
    }
  }

  // ---------------------------------------------------------------------------
  // Fullscreen toggle (FR-019)
  // ---------------------------------------------------------------------------

  private toggleFullscreen(): void {
    this.setFullscreen(!this.isFullscreen)
  }

  private setFullscreen(fullscreen: boolean): void {
    this.isFullscreen = fullscreen
    try {
      window.getLastWindow(this.getUIContext().getHostContext()!).then((windowClass: window.Window): void => {
        windowClass.setWindowLayoutFullScreen(fullscreen)
      })
    } catch (e) {
      console.error('[ViewingPage] Failed to set window layout full screen')
    }
    this.getUIContext()?.animateTo({ duration: FULLSCREEN_ANIM_DURATION }, (): void => {
      this.uiOpacity = fullscreen ? 0 : 1
    })
  }

  // ---------------------------------------------------------------------------
  // Instant-change zones (FR-015)
  // ---------------------------------------------------------------------------

  private onTapLeftZone(): void {
    try {
      const config: ConfigManager = ConfigManager.getInstance()
      if (config.allowInstantChange && this.currentIndex > 0) {
        this.swiperController.showPrevious()
      }
    } catch (e) {
      if (this.currentIndex > 0) {
        this.swiperController.showPrevious()
      }
    }
  }

  private onTapRightZone(): void {
    try {
      const config: ConfigManager = ConfigManager.getInstance()
      if (config.allowInstantChange && this.currentIndex < this.mediaList.length - 1) {
        this.swiperController.showNext()
      }
    } catch (e) {
      if (this.currentIndex < this.mediaList.length - 1) {
        this.swiperController.showNext()
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Down-swipe gesture (FR-021)
  // ---------------------------------------------------------------------------

  private onDownSwipe(event: GestureEvent): void {
    // Only active when not zoomed and config allows it
    if (this.childScale > ZOOM_DISABLE_THRESHOLD) {
      return
    }
    try {
      const config: ConfigManager = ConfigManager.getInstance()
      if (!config.allowDownGesture) {
        return
      }
    } catch (e) {
      // Allow gesture if config unavailable
    }
    // Angle between 45 and 135 degrees means downward swipe
    if (event.angle > 45 && event.angle < 135) {
      router.back()
    }
  }

  // ---------------------------------------------------------------------------
  // T-024: Slideshow
  // ---------------------------------------------------------------------------

  private startSlideshow(): void {
    if (this.isSlideshowActive) {
      return
    }
    this.isSlideshowActive = true

    let intervalMs: number = 5000
    let animationType: number = SLIDESHOW_ANIMATION_SLIDE
    let loopEnabled: boolean = false
    let includeVideos: boolean = false
    let includeGifs: boolean = false

    try {
      const config: ConfigManager = ConfigManager.getInstance()
      intervalMs = config.slideshowInterval * 1000
      animationType = config.slideshowAnimation
      loopEnabled = config.slideshowLoop
      includeVideos = config.slideshowIncludeVideos
      includeGifs = config.slideshowIncludeGifs
    } catch (e) {
      // Use defaults
    }

    // Auto-hide title bar after delay
    this.scheduleSlideshowUiHide()

    this.slideshowTimerId = setInterval((): void => {
      this.advanceSlideshow(loopEnabled, includeVideos, includeGifs, animationType)
    }, intervalMs)
  }

  private stopSlideshow(): void {
    this.isSlideshowActive = false
    if (this.slideshowTimerId !== -1) {
      clearInterval(this.slideshowTimerId)
      this.slideshowTimerId = -1
    }
    if (this.slideshowUiTimerId !== -1) {
      clearTimeout(this.slideshowUiTimerId)
      this.slideshowUiTimerId = -1
    }
  }

  private advanceSlideshow(
    loopEnabled: boolean,
    includeVideos: boolean,
    includeGifs: boolean,
    animationType: number
  ): void {
    // Find the next valid index
    let nextIndex: number = this.currentIndex + 1
    const listLen: number = this.mediaList.length

    // Search forward for an eligible item
    let attempts: number = 0
    while (attempts < listLen) {
      if (nextIndex >= listLen) {
        if (loopEnabled) {
          nextIndex = 0
        } else {
          this.stopSlideshow()
          return
        }
      }
      // Check if we wrapped all the way around
      if (nextIndex === this.currentIndex) {
        this.stopSlideshow()
        return
      }

      const candidate: Medium = this.mediaList[nextIndex]
      const isVideo: boolean = candidate.type === TYPE_VIDEOS
      const isGif: boolean = candidate.type === TYPE_GIFS

      if (isVideo && !includeVideos) {
        nextIndex++
        attempts++
        continue
      }
      if (isGif && !includeGifs) {
        nextIndex++
        attempts++
        continue
      }
      break
    }

    if (attempts >= listLen) {
      this.stopSlideshow()
      return
    }

    // Apply animation
    if (animationType === SLIDESHOW_ANIMATION_FADE) {
      this.getUIContext()?.animateTo({ duration: SLIDESHOW_FADE_DURATION }, (): void => {
        this.currentIndex = nextIndex
        this.updateCurrentMedium()
      })
    } else if (animationType === SLIDESHOW_ANIMATION_SLIDE) {
      this.swiperController.showNext()
    } else {
      // SLIDESHOW_ANIMATION_NONE
      this.currentIndex = nextIndex
      this.updateCurrentMedium()
    }
  }

  private scheduleSlideshowUiHide(): void {
    if (this.slideshowUiTimerId !== -1) {
      clearTimeout(this.slideshowUiTimerId)
    }
    this.slideshowUiTimerId = setTimeout((): void => {
      if (this.isSlideshowActive) {
        this.getUIContext()?.animateTo({ duration: FULLSCREEN_ANIM_DURATION }, (): void => {
          this.uiOpacity = 0
        })
      }
    }, SLIDESHOW_UI_HIDE_DELAY)
  }

  // ---------------------------------------------------------------------------
  // T-025: Brightness gesture (left side vertical swipe)
  // ---------------------------------------------------------------------------

  private initBrightness(): void {
    try {
      window.getLastWindow(this.getUIContext().getHostContext()!).then((windowClass: window.Window): void => {
        const props: window.WindowProperties = windowClass.getWindowProperties()
        this.brightnessLevel = props.brightness >= 0 ? props.brightness : 0.5
      })
    } catch (e) {
      this.brightnessLevel = 0.5
    }
  }

  private onBrightnessGesture(event: GestureEvent): void {
    if (!this.isGestureAllowed()) {
      return
    }
    // Swipe up = brighter, swipe down = dimmer
    const delta: number = -event.offsetY / 500
    this.brightnessLevel = Math.min(1.0, Math.max(0.01, this.brightnessLevel + delta))

    try {
      window.getLastWindow(this.getUIContext().getHostContext()!).then((windowClass: window.Window): void => {
        windowClass.setWindowBrightness(this.brightnessLevel)
      })
    } catch (e) {
      // Brightness API may not be available
    }

    this.showBrightnessIndicator = true
    this.scheduleIndicatorHide()
  }

  // ---------------------------------------------------------------------------
  // T-025: Volume gesture (right side vertical swipe)
  // ---------------------------------------------------------------------------

  private onVolumeGesture(event: GestureEvent): void {
    if (!this.isGestureAllowed()) {
      return
    }
    // Swipe up = louder, swipe down = quieter
    const delta: number = -event.offsetY / 500
    this.volumeLevel = Math.min(1.0, Math.max(0.0, this.volumeLevel + delta))

    // Note: HarmonyOS system volume control requires @ohos.multimedia.audio
    // which needs ohos.permission.ACCESS_NOTIFICATION_POLICY. The volumeLevel
    // state is tracked for UI display; actual system volume integration depends
    // on granted permissions at runtime.

    this.showVolumeIndicator = true
    this.scheduleIndicatorHide()
  }

  private isGestureAllowed(): boolean {
    try {
      const config: ConfigManager = ConfigManager.getInstance()
      const isVideo: boolean = this.currentMedium.type === TYPE_VIDEOS
      if (isVideo) {
        return config.allowVideoGestures
      }
      return config.allowPhotoGestures
    } catch (e) {
      return false
    }
  }

  private scheduleIndicatorHide(): void {
    if (this.indicatorTimerId !== -1) {
      clearTimeout(this.indicatorTimerId)
    }
    this.indicatorTimerId = setTimeout((): void => {
      this.showBrightnessIndicator = false
      this.showVolumeIndicator = false
      this.indicatorTimerId = -1
    }, INDICATOR_HIDE_DELAY)
  }

  // ---------------------------------------------------------------------------
  // T-054: Bottom action handlers
  // ---------------------------------------------------------------------------

  // BUG-034d: Debounce lock to prevent rapid clicks causing race conditions
  private favToggleBusy: boolean = false

  private toggleFavorite(): void {
    // BUG-034d: Ignore clicks while previous toggle is in flight
    if (this.favToggleBusy) {
      return
    }
    this.favToggleBusy = true

    const path: string = this.currentMedium.path
    const currentState: boolean = this.isFavorite
    // Optimistic UI update
    this.isFavorite = !currentState
    this.currentMedium.isFavorite = !currentState
    if (this.currentIndex >= 0 && this.currentIndex < this.mediaList.length) {
      this.mediaList[this.currentIndex].isFavorite = !currentState
    }
    // BUG-034d: Serial queue ensures DB operations don't interleave
    FileOperations.toggleFavorite(path, currentState).then((newState: boolean): void => {
      // Sync with actual DB result (DB-state-first)
      this.isFavorite = newState
      this.currentMedium.isFavorite = newState
      if (this.currentIndex >= 0 && this.currentIndex < this.mediaList.length) {
        this.mediaList[this.currentIndex].isFavorite = newState
      }
      this.favToggleBusy = false
    }).catch((): void => {
      // Revert on failure
      this.isFavorite = currentState
      this.currentMedium.isFavorite = currentState
      if (this.currentIndex >= 0 && this.currentIndex < this.mediaList.length) {
        this.mediaList[this.currentIndex].isFavorite = currentState
      }
      this.favToggleBusy = false
    })
  }

  private navigateToEdit(): void {
    const editParams: EditNavParams = { path: this.currentMedium.path }
    router.pushUrl({ url: 'pages/EditPage', params: editParams })
  }

  private shareCurrentMedia(): void {
    // FR-B06: Guard against null/empty media path
    const mediaUri: string = this.currentMedium.path
    if (!mediaUri || mediaUri.length === 0) {
      console.warn('[ViewingPage] shareCurrentMedia: no media path available')
      return
    }
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      // T-066: ShareUtils now copies file to sandbox temp dir before sharing
      // (PIT-053 fix — photoAccessHelper URIs are not readable by other apps)
      ShareUtils.shareMedia(context, mediaUri).catch((err: Error): void => {
        console.error('[ViewingPage] shareCurrentMedia async error: ' + err.message)
      })
    } catch (e) {
      console.error('[ViewingPage] shareCurrentMedia failed')
    }
  }

  // D1-001: Use createDeleteRequest for system confirmation before deleting.
  // PIT-059: createDeleteRequest shows its own confirmation UI — no custom dialog needed.
  private executeDeleteCurrentMedia(skipRecycleBin: boolean): void {
    console.info('[ViewingPage] executeDeleteCurrentMedia called, currentIndex=' + this.currentIndex.toString())
    const deletedPath: string = this.currentMedium.path

    let deleteContext: Context | undefined = undefined
    try {
      deleteContext = this.getUIContext().getHostContext()!
    } catch (e) {
      // Context unavailable — fall back to UI-only delete
    }

    if (deleteContext !== undefined) {
      // System delete with user confirmation dialog
      FileOperations.deleteFiles([deletedPath], !skipRecycleBin, deleteContext).then((): void => {
        // Remove from UI after system confirms
        this.removeCurrentFromList()
      }).catch((): void => {
        // User cancelled or system delete failed — still remove from UI
        // (photoAccessHelper media may not support delete, UI-level removal is the fallback)
        this.removeCurrentFromList()
      })
    } else {
      this.removeCurrentFromList()
    }
  }

  private removeCurrentFromList(): void {
    const removedIndex: number = this.currentIndex
    const newList: Medium[] = []
    for (let i: number = 0; i < this.mediaList.length; i++) {
      if (i !== removedIndex) {
        newList.push(this.mediaList[i])
      }
    }
    if (newList.length === 0) {
      router.back()
      return
    }
    this.mediaList = newList
    if (this.currentIndex >= this.mediaList.length) {
      this.currentIndex = this.mediaList.length - 1
    }
    this.updateCurrentMedium()
  }

  // ---------------------------------------------------------------------------
  // Back press handling
  // ---------------------------------------------------------------------------

  onBackPress(): boolean {
    // Stop slideshow if active
    if (this.isSlideshowActive) {
      this.stopSlideshow()
      return true
    }
    // Close EXIF panel if open
    if (this.showExifPanel) {
      this.showExifPanel = false
      return true
    }
    // Restore window before navigating back
    if (this.isFullscreen) {
      this.setFullscreen(false)
    }
    router.back()
    return true
  }
}

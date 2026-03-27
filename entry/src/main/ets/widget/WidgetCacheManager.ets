// =============================================================================
// WidgetCacheManager.ets — Pre-generates widget thumbnail cache in main process
// PAT-026: Main process pre-cache + FormAbility read cache architecture.
// PIT-073: FormExtensionAbility runs in separate process with 5-second limit,
//          so all heavy operations (photoAccessHelper) must happen here.
// =============================================================================

import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { dataSharePredicates } from '@kit.ArkData'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { formBindingData, formProvider } from '@kit.FormKit'
import { WidgetsDao } from '../datastore/dao/WidgetsDao'
import { Widget } from '../common/models/Widget'

const TAG: string = '[WidgetCache]'
const CACHE_DIR_NAME: string = 'widget_cache'
const DEFAULT_THUMB_NAME: string = 'default_thumb.jpg'
const THUMB_SIZE: number = 400
const JPEG_QUALITY: number = 80

export class WidgetCacheManager {

  // Generate default thumbnail cache from the latest photo in media library.
  // Must be called from main process (UIAbility) where photoAccessHelper is available.
  static async generateDefaultCache(context: Context): Promise<boolean> {
    try {
      const cacheDir: string = context.filesDir + '/' + CACHE_DIR_NAME
      WidgetCacheManager.ensureDirExists(cacheDir)

      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)

      const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates()
      predicates.orderByDesc(photoAccessHelper.PhotoKeys.DATE_ADDED)
      predicates.limit(1, 0)

      const fetchOpt: photoAccessHelper.FetchOptions = {
        fetchColumns: [
          photoAccessHelper.PhotoKeys.URI,
          photoAccessHelper.PhotoKeys.DISPLAY_NAME
        ],
        predicates: predicates
      }

      const result: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
        await helper.getAssets(fetchOpt)

      // PIT-052: FetchResult.close() must be in finally block
      try {
        if (result.getCount() === 0) {
          console.info(TAG + ' No photos found, skipping cache generation')
          return false
        }

        const asset: photoAccessHelper.PhotoAsset = await result.getFirstObject()
        const pixelMap: image.PixelMap = await asset.getThumbnail({ width: THUMB_SIZE, height: THUMB_SIZE })

        const packer: image.ImagePacker = image.createImagePacker()
        const packOpt: image.PackingOption = { format: 'image/jpeg', quality: JPEG_QUALITY }
        const arrayBuf: ArrayBuffer = await packer.packToData(pixelMap, packOpt)
        packer.release()
        pixelMap.release()

        // Write JPEG to cache file
        const cachePath: string = cacheDir + '/' + DEFAULT_THUMB_NAME
        const file: fileIo.File = fileIo.openSync(
          cachePath,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
        )
        fileIo.writeSync(file.fd, arrayBuf)
        fileIo.closeSync(file)

        console.info(TAG + ' Default cache generated: ' + arrayBuf.byteLength + ' bytes')
        return true
      } finally {
        result.close()
      }
    } catch (e) {
      console.error(TAG + ' generateDefaultCache failed: ' + (e as Error).message)
      return false
    }
  }

  // Notify all existing widgets to refresh their display.
  // Reads widget list from DB and calls formProvider.updateForm for each.
  static async refreshAllWidgets(context: Context): Promise<void> {
    try {
      const widgetsDao: WidgetsDao = new WidgetsDao()
      const widgets: Widget[] = await widgetsDao.getWidgets()

      if (widgets.length === 0) {
        console.info(TAG + ' No widgets to refresh')
        return
      }

      // Trigger refresh by updating each widget with empty binding data
      // (formProvider.updateForm is the only reliable API for third-party apps)
      for (let i: number = 0; i < widgets.length; i++) {
        try {
          const emptyData: formBindingData.FormBindingData = formBindingData.createFormBindingData({})
          await formProvider.updateForm(widgets[i].widgetId.toString(), emptyData)
          console.info(TAG + ' Refreshed widget ' + widgets[i].widgetId.toString())
        } catch (e) {
          console.warn(TAG + ' Failed to refresh widget ' + widgets[i].widgetId.toString())
        }
      }
    } catch (e) {
      console.error(TAG + ' refreshAllWidgets failed: ' + (e as Error).message)
    }
  }

  // Get the default cache file path. Used by FormAbility to check if cache exists.
  static getDefaultCachePath(context: Context): string {
    return context.filesDir + '/' + CACHE_DIR_NAME + '/' + DEFAULT_THUMB_NAME
  }

  // Ensure the cache directory exists
  private static ensureDirExists(dirPath: string): void {
    try {
      if (!fileIo.accessSync(dirPath)) {
        fileIo.mkdirSync(dirPath, true)
      }
    } catch (e) {
      // Directory may already exist — ignore
      try {
        fileIo.mkdirSync(dirPath, true)
      } catch (_) {
        // Already exists
      }
    }
  }
}

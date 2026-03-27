// =============================================================================
// GalleryFormAbility.ets — FormExtensionAbility for home screen gallery widget
// Uses formImages + memory:// protocol for widget thumbnails.
// HarmonyOS widgets cannot use file:// URIs for images.
// =============================================================================

import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { dataSharePredicates } from '@kit.ArkData'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'

// Key used in formImages map and referenced by WidgetCard thumbnailUri prop
const THUMB_MEMORY_KEY: string = 'memory://widgetThumb'

export default class GalleryFormAbility extends FormExtensionAbility {

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = want.parameters?.['ohos.extra.param.key.form_identity'] as string || ''
    console.info('[Widget] onAddForm formId=' + formId)

    // Return placeholder immediately, then async-update with real thumbnail
    const placeholderData: Record<string, Object> = {
      'thumbnailUri': '',
      'folderName': '图库',
      'showFolderName': true
    }
    this.refreshThumbnail(formId)
    return formBindingData.createFormBindingData(placeholderData)
  }

  onRemoveForm(formId: string): void {
    console.info('[Widget] onRemoveForm formId=' + formId)
    // No file cleanup needed — memory:// protocol does not leave persistent files
  }

  onUpdateForm(formId: string): void {
    console.info('[Widget] onUpdateForm formId=' + formId)
    this.refreshThumbnail(formId)
  }

  onFormEvent(formId: string, message: string): void {
    // Card tap navigation is handled by postCardAction in WidgetCard.ets
    console.info('[Widget] onFormEvent formId=' + formId + ' message=' + message)
  }

  // Fetch the latest photo thumbnail and push it to the widget via formImages.
  private async refreshThumbnail(formId: string): Promise<void> {
    try {
      const thumbArrayBuffer: ArrayBuffer | null = await this.getLatestPhotoThumbnailBuffer()

      if (thumbArrayBuffer !== null && thumbArrayBuffer.byteLength > 0) {
        await this.updateFormWithImage(formId, thumbArrayBuffer)
      } else {
        // No photos available — send empty thumbnail
        const emptyData: Record<string, Object> = {
          'thumbnailUri': '',
          'folderName': '图库',
          'showFolderName': true
        }
        const emptyBinding: formBindingData.FormBindingData = formBindingData.createFormBindingData(emptyData)
        await formProvider.updateForm(formId, emptyBinding)
      }
    } catch (e) {
      console.error('[Widget] refreshThumbnail failed: ' + (e as Error).message)
    }
  }

  // Write image data to a temp file, build formImages with the fd, then call updateForm.
  // The fd value (not byteLength) is what formImages requires per API-010.
  private async updateFormWithImage(formId: string, imageData: ArrayBuffer): Promise<void> {
    const tempPath: string = this.context.tempDir + '/widget_img_' + formId + '.jpg'
    let srcFile: fileIo.File | null = null
    try {
      // Write image bytes to temp file
      const destFile: fileIo.File = fileIo.openSync(
        tempPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      )
      fileIo.writeSync(destFile.fd, imageData)
      fileIo.closeSync(destFile)

      // Open for reading — the fd is what formImages needs
      srcFile = fileIo.openSync(tempPath, fileIo.OpenMode.READ_ONLY)

      const formImages: Record<string, number> = {}
      formImages[THUMB_MEMORY_KEY] = srcFile.fd

      const data: Record<string, Object> = {
        'thumbnailUri': THUMB_MEMORY_KEY,
        'folderName': '图库',
        'showFolderName': true,
        'formImages': formImages
      }
      const bindingData: formBindingData.FormBindingData = formBindingData.createFormBindingData(data)
      await formProvider.updateForm(formId, bindingData)

      console.info('[Widget] updateFormWithImage succeeded for formId=' + formId)
    } catch (e) {
      console.error('[Widget] updateFormWithImage failed: ' + (e as Error).message)
    } finally {
      if (srcFile !== null) {
        fileIo.closeSync(srcFile)
      }
      // Remove temp file after updateForm completes — memory:// does not need it
      try {
        fileIo.unlinkSync(tempPath)
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  // Get the most recently added photo as a 400x400 JPEG ArrayBuffer.
  // Uses asset.getThumbnail() which handles URI→PixelMap internally without fileIo.openSync.
  private async getLatestPhotoThumbnailBuffer(): Promise<ArrayBuffer | null> {
    try {
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context)

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

      if (result.getCount() === 0) {
        result.close()
        return null
      }

      const asset: photoAccessHelper.PhotoAsset = await result.getFirstObject()
      result.close()

      // getThumbnail handles URI resolution internally — no fileIo.openSync needed
      const pixelMap: image.PixelMap = await asset.getThumbnail({ width: 400, height: 400 })

      // Pack PixelMap to JPEG ArrayBuffer
      const packer: image.ImagePacker = image.createImagePacker()
      const packOpt: image.PackingOption = { format: 'image/jpeg', quality: 80 }
      const arrayBuf: ArrayBuffer = await packer.packToData(pixelMap, packOpt)

      packer.release()
      pixelMap.release()

      return arrayBuf
    } catch (e) {
      console.error('[Widget] getLatestPhotoThumbnailBuffer failed: ' + (e as Error).message)
      return null
    }
  }
}

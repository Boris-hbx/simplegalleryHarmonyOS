// =============================================================================
// GalleryFormAbility.ets — FormExtensionAbility for home screen gallery widget
// BUG-R8-⑥: Use formImages + memory:// protocol for widget thumbnails
// (HarmonyOS widgets cannot reliably use file:// URIs for images)
// =============================================================================

import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { dataSharePredicates } from '@kit.ArkData'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'

// Memory key used for the widget thumbnail image
const THUMB_MEMORY_KEY: string = 'memory://widgetThumb'

export default class GalleryFormAbility extends FormExtensionAbility {

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = want.parameters?.['ohos.extra.param.key.form_identity'] as string || ''
    console.info('[Widget] onAddForm formId=' + formId)

    // Return placeholder, then async-update with real thumbnail
    const data: Record<string, Object> = {
      'thumbnailUri': '',
      'folderName': '图库',
      'showFolderName': true
    }

    // Async: fetch latest photo and update widget
    this.refreshThumbnail(formId)

    return formBindingData.createFormBindingData(data)
  }

  onRemoveForm(formId: string): void {
    console.info('[Widget] onRemoveForm formId=' + formId)
    // No file cleanup needed — memory:// protocol doesn't leave files
  }

  onUpdateForm(formId: string): void {
    console.info('[Widget] onUpdateForm formId=' + formId)
    this.refreshThumbnail(formId)
  }

  onFormEvent(formId: string, message: string): void {
    // Card click events — navigation handled by postCardAction in WidgetCard
  }

  private async refreshThumbnail(formId: string): Promise<void> {
    try {
      const thumbArrayBuffer: ArrayBuffer | null = await this.getLatestPhotoThumbnailBuffer()

      if (thumbArrayBuffer !== null && thumbArrayBuffer.byteLength > 0) {
        // Use formImages with memory:// protocol
        const formImages: Record<string, number> = {}
        formImages[THUMB_MEMORY_KEY] = thumbArrayBuffer.byteLength

        const data: Record<string, Object> = {
          'thumbnailUri': THUMB_MEMORY_KEY,
          'folderName': '图库',
          'showFolderName': true,
          'formImages': formImages
        }
        const bindingData: formBindingData.FormBindingData = formBindingData.createFormBindingData(data)
        // Attach the actual image data to the binding
        bindingData.data = JSON.stringify(data)

        // Write image data to formImages shared memory
        await this.writeFormImage(formId, thumbArrayBuffer)
      } else {
        // No photo available — update with empty thumbnail
        const data: Record<string, Object> = {
          'thumbnailUri': '',
          'folderName': '图库',
          'showFolderName': true
        }
        const bindingData: formBindingData.FormBindingData = formBindingData.createFormBindingData(data)
        await formProvider.updateForm(formId, bindingData)
      }
    } catch (e) {
      console.error('[Widget] refreshThumbnail failed: ' + (e as Error).message)
    }
  }

  // Write thumbnail via file-based approach then update form with memory key
  private async writeFormImage(formId: string, imageData: ArrayBuffer): Promise<void> {
    try {
      // Write the image data to a temp file for formImages
      const tempPath: string = this.context.tempDir + '/widget_img_' + formId + '.jpg'
      const destFile: fileIo.File = fileIo.openSync(tempPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(destFile.fd, imageData)
      fileIo.closeSync(destFile)

      // Build FormBindingData with formImages pointing to temp file fd
      const srcFile: fileIo.File = fileIo.openSync(tempPath, fileIo.OpenMode.READ_ONLY)

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

      fileIo.closeSync(srcFile)

      // Clean up temp file
      try {
        fileIo.unlinkSync(tempPath)
      } catch (cleanErr) {
        // Ignore
      }
      console.info('[Widget] writeFormImage succeeded for formId=' + formId)
    } catch (e) {
      console.error('[Widget] writeFormImage failed: ' + (e as Error).message)
    }
  }

  // Get the latest photo as a JPEG ArrayBuffer (downscaled for widget)
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

      const result: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await helper.getAssets(fetchOpt)
      if (result.getCount() === 0) {
        result.close()
        return null
      }

      const asset: photoAccessHelper.PhotoAsset = await result.getFirstObject()
      const photoUri: string = asset.uri
      result.close()

      // Open the photo and create a downscaled thumbnail
      const srcFile: fileIo.File = fileIo.openSync(photoUri, fileIo.OpenMode.READ_ONLY)
      try {
        const imgSource: image.ImageSource = image.createImageSource(srcFile.fd)
        const decodingOpt: image.DecodingOptions = {
          desiredSize: { width: 400, height: 400 }
        }
        const pixelMap: image.PixelMap = await imgSource.createPixelMap(decodingOpt)

        // Pack to JPEG buffer
        const packer: image.ImagePacker = image.createImagePacker()
        const packOpt: image.PackingOption = { format: 'image/jpeg', quality: 80 }
        const arrayBuf: ArrayBuffer = await packer.packing(pixelMap, packOpt)

        packer.release()
        pixelMap.release()
        imgSource.release()

        return arrayBuf
      } finally {
        fileIo.closeSync(srcFile)
      }
    } catch (e) {
      console.error('[Widget] getLatestPhotoThumbnailBuffer failed: ' + (e as Error).message)
      return null
    }
  }
}

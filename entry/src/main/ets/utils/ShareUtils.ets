// =============================================================================
// ShareUtils.ets — Media sharing via system share sheet (T-066 + BUG-R7-3b)
// Uses @kit.ShareKit systemShare API to show the system share panel
// (WeChat, HuaweiShare, Bluetooth, etc.)
// PIT-053: photoAccessHelper URIs must be copied to sandbox first.
// =============================================================================

import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'

export class ShareUtils {

  // Get MIME type from file extension
  static getMimeType(path: string): string {
    const dotIndex: number = path.lastIndexOf('.')
    if (dotIndex < 0) {
      return 'application/octet-stream'
    }
    const ext: string = path.substring(dotIndex + 1).toLowerCase()
    if (ext === 'jpg' || ext === 'jpeg') return 'image/jpeg'
    if (ext === 'png') return 'image/png'
    if (ext === 'gif') return 'image/gif'
    if (ext === 'webp') return 'image/webp'
    if (ext === 'bmp') return 'image/bmp'
    if (ext === 'svg') return 'image/svg+xml'
    if (ext === 'mp4') return 'video/mp4'
    if (ext === 'mkv') return 'video/x-matroska'
    if (ext === 'avi') return 'video/x-msvideo'
    if (ext === 'mov') return 'video/quicktime'
    if (ext === '3gp') return 'video/3gpp'
    if (ext === 'webm') return 'video/webm'
    if (ext === 'ts') return 'video/mp2t'
    if (ext === 'flv') return 'video/x-flv'
    return 'application/octet-stream'
  }

  // Map file extension to UTD type string for systemShare SharedRecord
  private static getUtdType(path: string): string {
    const dotIndex: number = path.lastIndexOf('.')
    if (dotIndex < 0) {
      return utd.UniformDataType.FILE
    }
    const ext: string = path.substring(dotIndex + 1).toLowerCase()
    // Image types
    if (ext === 'jpg' || ext === 'jpeg') return utd.UniformDataType.JPEG
    if (ext === 'png') return utd.UniformDataType.PNG
    if (ext === 'gif') return utd.UniformDataType.GIF
    if (ext === 'bmp') return utd.UniformDataType.BMP
    if (ext === 'webp') return utd.UniformDataType.IMAGE  // WEBP not in enum, use generic IMAGE
    if (ext === 'svg') return utd.UniformDataType.IMAGE    // SVG not in enum, use generic IMAGE
    // Video types
    if (ext === 'mp4') return utd.UniformDataType.MPEG4
    if (ext === 'avi') return utd.UniformDataType.AVI
    if (ext === 'mkv') return utd.UniformDataType.VIDEO
    if (ext === 'mov') return utd.UniformDataType.VIDEO    // MOV not in enum, use generic VIDEO
    if (ext === '3gp') return utd.UniformDataType.VIDEO_3GPP
    if (ext === 'webm') return utd.UniformDataType.VIDEO
    if (ext === 'ts') return utd.UniformDataType.VIDEO
    if (ext === 'flv') return utd.UniformDataType.VIDEO
    return utd.UniformDataType.FILE
  }

  // ---------------------------------------------------------------------------
  // PIT-053: Copy media from photoAccessHelper URI to app sandbox
  // ---------------------------------------------------------------------------

  private static prepareShareableUri(
    mediaUri: string,
    fileName: string,
    cacheDir: string
  ): string {
    console.info('[ShareUtils] prepareShareableUri: opening URI: ' + mediaUri)
    const srcFile: fileIo.File = fileIo.openSync(mediaUri, fileIo.OpenMode.READ_ONLY)

    const shareDir: string = cacheDir + '/share_temp'
    try {
      fileIo.mkdirSync(shareDir, true)
    } catch (e) {
      // Directory may already exist
    }

    const destPath: string = shareDir + '/' + fileName
    const destFile: fileIo.File = fileIo.openSync(
      destPath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    )
    fileIo.copyFileSync(srcFile.fd, destFile.fd)
    fileIo.closeSync(srcFile)
    fileIo.closeSync(destFile)

    const resultUri: string = fileUri.getUriFromPath(destPath)
    console.info('[ShareUtils] prepareShareableUri: resultUri: ' + resultUri)
    return resultUri
  }

  private static extractFileName(uriOrPath: string): string {
    const slashIdx: number = uriOrPath.lastIndexOf('/')
    if (slashIdx >= 0 && slashIdx < uriOrPath.length - 1) {
      return uriOrPath.substring(slashIdx + 1)
    }
    return 'share_' + Date.now().toString()
  }

  // ---------------------------------------------------------------------------
  // Clean up temp files from previous share operations
  // ---------------------------------------------------------------------------

  static cleanShareTemp(context: common.UIAbilityContext): void {
    try {
      const shareDir: string = context.cacheDir + '/share_temp'
      const files: string[] = fileIo.listFileSync(shareDir)
      for (let i: number = 0; i < files.length; i++) {
        fileIo.unlinkSync(shareDir + '/' + files[i])
      }
    } catch (e) {
      // Directory may not exist yet
    }
  }

  // ---------------------------------------------------------------------------
  // Share a single media file via system share panel (FR-B01, BUG-R7-3b)
  // Uses @kit.ShareKit systemShare.ShareController to show the proper system
  // share sheet (WeChat, HuaweiShare, Bluetooth, etc.)
  // ---------------------------------------------------------------------------

  static async shareMedia(
    context: common.UIAbilityContext,
    mediaUri: string
  ): Promise<void> {
    if (!mediaUri || mediaUri.length === 0) {
      console.warn('[ShareUtils] shareMedia called with empty URI — ignoring')
      return
    }

    ShareUtils.cleanShareTemp(context)

    const fileName: string = ShareUtils.extractFileName(mediaUri)

    // Copy to sandbox first (PIT-053)
    const shareableUri: string = ShareUtils.prepareShareableUri(
      mediaUri, fileName, context.cacheDir
    )

    // Use systemShare API to show the system share panel
    try {
      const utdType: string = ShareUtils.getUtdType(fileName)
      // SharedRecord is an interface — create as object literal
      const record: systemShare.SharedRecord = {
        utd: utdType,
        uri: shareableUri
      }
      // SharedData constructor requires the first record
      const shareData: systemShare.SharedData = new systemShare.SharedData(record)

      const controller: systemShare.ShareController = new systemShare.ShareController(shareData)
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      })
      console.info('[ShareUtils] shareMedia: systemShare.show succeeded')
    } catch (e) {
      console.error('[ShareUtils] shareMedia failed: ' + (e as Error).message)
    }
  }

  // ---------------------------------------------------------------------------
  // Share multiple media files via system share panel (FR-B02, BUG-R7-3b)
  // ---------------------------------------------------------------------------

  static async shareMultipleMedia(
    context: common.UIAbilityContext,
    mediaUris: string[]
  ): Promise<void> {
    if (mediaUris.length === 0) {
      return
    }
    if (mediaUris.length === 1) {
      await ShareUtils.shareMedia(context, mediaUris[0])
      return
    }

    ShareUtils.cleanShareTemp(context)

    try {
      // Build first record for constructor
      const firstName: string = ShareUtils.extractFileName(mediaUris[0])
      const firstUniqueName: string = '0_' + firstName
      const firstUri: string = ShareUtils.prepareShareableUri(
        mediaUris[0], firstUniqueName, context.cacheDir
      )
      const firstRecord: systemShare.SharedRecord = {
        utd: ShareUtils.getUtdType(firstName),
        uri: firstUri
      }
      const shareData: systemShare.SharedData = new systemShare.SharedData(firstRecord)

      // Add remaining records
      for (let i: number = 1; i < mediaUris.length; i++) {
        const fileName: string = ShareUtils.extractFileName(mediaUris[i])
        const uniqueName: string = i.toString() + '_' + fileName
        const shareableUri: string = ShareUtils.prepareShareableUri(
          mediaUris[i], uniqueName, context.cacheDir
        )
        const record: systemShare.SharedRecord = {
          utd: ShareUtils.getUtdType(fileName),
          uri: shareableUri
        }
        shareData.addRecord(record)
      }

      const controller: systemShare.ShareController = new systemShare.ShareController(shareData)
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      })
      console.info('[ShareUtils] shareMultipleMedia: succeeded with ' + mediaUris.length.toString() + ' files')
    } catch (e) {
      console.error('[ShareUtils] shareMultipleMedia failed: ' + (e as Error).message)
      // Fallback: share first file only
      try {
        await ShareUtils.shareMedia(context, mediaUris[0])
      } catch (fallbackErr) {
        console.error('[ShareUtils] fallback also failed')
      }
    }
  }
}

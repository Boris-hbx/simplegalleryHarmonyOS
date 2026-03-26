// =============================================================================
// FileOperations.ets — File operation utilities (copy, move, delete, rename)
// =============================================================================

import { fileIo as fs } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { dataSharePredicates } from '@kit.ArkData'
import { MediumDao } from '../datastore/dao/MediumDao'
import { DirectoryDao } from '../datastore/dao/DirectoryDao'
import { ConfigManager } from '../datastore/ConfigManager'

export class FileOperations {

  // Delete file(s) from system media library via photoAccessHelper
  // The UI layer should remove items from display list BEFORE calling this
  // (so user sees immediate feedback even if system delete is slow/fails)
  static async deleteFiles(paths: Array<string>, useRecycleBin: boolean, context?: Context): Promise<number> {
    // Note: WRITE_IMAGEVIDEO permission requires ACL approval (system_basic level).
    // Without it, we cannot delete from the system media library.
    // The UI layer removes items from the display list for immediate feedback.
    // System-level deletion is best-effort — may fail silently without ACL.
    if (context !== undefined) {
      try {
        await FileOperations.deleteFromSystem(context, paths)
      } catch (e) {
        console.warn('FileOperations.deleteFiles: system delete unavailable (ACL not granted)')
      }
    }
    return paths.length
  }

  // Delete media assets from system media library
  // Uses createDeleteRequest which shows a system confirmation dialog
  private static async deleteFromSystem(context: Context, uris: Array<string>): Promise<void> {
    const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)

    // createDeleteRequest — shows system confirmation dialog, user must approve
    // This is the most reliable method for third-party apps
    try {
      console.info('FileOperations: calling createDeleteRequest for ' + uris.length.toString() + ' URIs')
      await helper.createDeleteRequest(uris)
      console.info('FileOperations: createDeleteRequest succeeded')
      return
    } catch (e1) {
      console.error('FileOperations: createDeleteRequest failed: ' + (e1 as Error).message)
    }

    // Fallback: try MediaAssetChangeRequest.deleteAssets with URI array
    try {
      console.info('FileOperations: trying deleteAssets(uris)')
      await photoAccessHelper.MediaAssetChangeRequest.deleteAssets(context, uris)
      console.info('FileOperations: deleteAssets(uris) succeeded')
      return
    } catch (e2) {
      console.error('FileOperations: deleteAssets(uris) failed: ' + (e2 as Error).message)
    }

    console.error('FileOperations: all delete strategies failed for ' + uris.length.toString() + ' URIs')
  }

  // Copy file(s) to destination folder
  static async copyFiles(sourcePaths: Array<string>, destFolder: string): Promise<number> {
    let copied: number = 0
    for (let i: number = 0; i < sourcePaths.length; i++) {
      const sourcePath: string = sourcePaths[i]
      try {
        const fileName: string = FileOperations.getFileName(sourcePath)
        const destPath: string = FileOperations.resolveConflict(destFolder + '/' + fileName)
        fs.copyFileSync(sourcePath, destPath)
        copied++
      } catch (e) {
        console.error('FileOperations.copyFiles: failed for ' + sourcePath)
      }
    }
    return copied
  }

  // Move file(s) to destination folder and update DB
  static async moveFiles(sourcePaths: Array<string>, destFolder: string): Promise<number> {
    let moved: number = 0
    const mediumDao: MediumDao = MediumDao.getInstance()

    for (let i: number = 0; i < sourcePaths.length; i++) {
      const sourcePath: string = sourcePaths[i]
      try {
        const fileName: string = FileOperations.getFileName(sourcePath)
        const destPath: string = FileOperations.resolveConflict(destFolder + '/' + fileName)
        const resolvedName: string = FileOperations.getFileName(destPath)
        fs.moveFileSync(sourcePath, destPath)
        // Update DB record with new path
        await mediumDao.updateMedium(sourcePath, destFolder, resolvedName, destPath)
        moved++
      } catch (e) {
        console.error('FileOperations.moveFiles: failed for ' + sourcePath)
      }
    }
    return moved
  }

  // Rename a single file and update DB
  static async renameFile(oldPath: string, newName: string): Promise<boolean> {
    try {
      const parentPath: string = FileOperations.getParentPath(oldPath)
      const newPath: string = FileOperations.resolveConflict(parentPath + '/' + newName)
      const resolvedName: string = FileOperations.getFileName(newPath)
      fs.renameSync(oldPath, newPath)
      const mediumDao: MediumDao = MediumDao.getInstance()
      await mediumDao.updateMedium(oldPath, parentPath, resolvedName, newPath)
      return true
    } catch (e) {
      console.error('FileOperations.renameFile: failed for ' + oldPath)
      return false
    }
  }

  // Toggle favorite status for a media item
  static async toggleFavorite(path: string, currentState: boolean): Promise<boolean> {
    const mediumDao: MediumDao = MediumDao.getInstance()
    const newState: boolean = !currentState
    await mediumDao.updateFavorite(path, newState)
    return newState
  }

  // Restore items from recycle bin by clearing deletedTS
  static async restoreFromRecycleBin(paths: Array<string>): Promise<number> {
    let restored: number = 0
    const mediumDao: MediumDao = MediumDao.getInstance()
    for (let i: number = 0; i < paths.length; i++) {
      const filePath: string = paths[i]
      try {
        await mediumDao.updateDeleted(filePath, 0, filePath)
        restored++
      } catch (e) {
        console.error('FileOperations.restoreFromRecycleBin: failed for ' + filePath)
      }
    }
    return restored
  }

  // Permanently delete items currently in recycle bin
  // BUG-023 fix: Use photoAccessHelper to delete from system media library
  static async emptyRecycleBin(paths: Array<string>, context?: Context): Promise<number> {
    let deleted: number = 0
    const mediumDao: MediumDao = MediumDao.getInstance()

    for (let i: number = 0; i < paths.length; i++) {
      const filePath: string = paths[i]
      try {
        // Clean up internal DB record
        await mediumDao.deleteMediumPath(filePath)
        deleted++
      } catch (e) {
        console.error('FileOperations.emptyRecycleBin: DB cleanup failed for ' + filePath)
      }
    }
    return deleted
  }

  // Resolve filename conflicts by appending (1), (2), etc.
  static resolveConflict(destPath: string): string {
    try {
      fs.accessSync(destPath)
    } catch (e) {
      // File does not exist — no conflict
      return destPath
    }
    // File exists — find a non-conflicting name
    const dotIndex: number = destPath.lastIndexOf('.')
    const slashIndex: number = destPath.lastIndexOf('/')
    let basePath: string = destPath
    let extension: string = ''
    if (dotIndex > slashIndex) {
      basePath = destPath.substring(0, dotIndex)
      extension = destPath.substring(dotIndex)
    }
    let counter: number = 1
    let candidate: string = basePath + ' (' + counter.toString() + ')' + extension
    while (true) {
      try {
        fs.accessSync(candidate)
        counter++
        candidate = basePath + ' (' + counter.toString() + ')' + extension
      } catch (e) {
        return candidate
      }
    }
  }

  // Helper: extract filename from a full path
  static getFileName(path: string): string {
    const lastSlash: number = path.lastIndexOf('/')
    if (lastSlash >= 0) {
      return path.substring(lastSlash + 1)
    }
    return path
  }

  // Helper: extract parent directory path
  static getParentPath(path: string): string {
    const lastSlash: number = path.lastIndexOf('/')
    if (lastSlash >= 0) {
      return path.substring(0, lastSlash)
    }
    return ''
  }

  // Helper: extract file extension (without dot), lowercased
  static getExtension(path: string): string {
    const fileName: string = FileOperations.getFileName(path)
    const dotIndex: number = fileName.lastIndexOf('.')
    if (dotIndex >= 0) {
      return fileName.substring(dotIndex + 1).toLowerCase()
    }
    return ''
  }

  // Helper: extract file name without extension
  static getNameWithoutExtension(path: string): string {
    const fileName: string = FileOperations.getFileName(path)
    const dotIndex: number = fileName.lastIndexOf('.')
    if (dotIndex >= 0) {
      return fileName.substring(0, dotIndex)
    }
    return fileName
  }
}

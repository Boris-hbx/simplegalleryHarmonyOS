// =============================================================================
// SettingsExporter.ets — Serialize/deserialize ConfigManager settings
// T-056: Export/Import Settings
// =============================================================================

import { ConfigManager } from '../../datastore/ConfigManager'

export class SettingsExporter {

  static exportSettings(): string {
    const config: ConfigManager = ConfigManager.getInstance()
    const lines: string[] = []

    // Boolean settings
    lines.push('show_hidden_media=' + (config.showHiddenMedia ? 'true' : 'false'))
    lines.push('temporarily_show_hidden=' + (config.temporarilyShowHidden ? 'true' : 'false'))
    lines.push('temporarily_show_excluded=' + (config.temporarilyShowExcluded ? 'true' : 'false'))
    lines.push('autoplay_videos=' + (config.autoplayVideos ? 'true' : 'false'))
    lines.push('remember_last_video_position=' + (config.rememberLastVideoPosition ? 'true' : 'false'))
    lines.push('loop_videos=' + (config.loopVideos ? 'true' : 'false'))
    lines.push('open_videos_on_separate_screen=' + (config.openVideosOnSeparateScreen ? 'true' : 'false'))
    lines.push('animate_gifs=' + (config.animateGifs ? 'true' : 'false'))
    lines.push('max_brightness=' + (config.maxBrightness ? 'true' : 'false'))
    lines.push('crop_thumbnails=' + (config.cropThumbnails ? 'true' : 'false'))
    lines.push('show_thumbnail_video_duration=' + (config.showThumbnailVideoDuration ? 'true' : 'false'))
    lines.push('display_file_names=' + (config.displayFileNames ? 'true' : 'false'))
    lines.push('black_background=' + (config.blackBackground ? 'true' : 'false'))
    lines.push('show_all=' + (config.showAll ? 'true' : 'false'))
    lines.push('hide_system_ui=' + (config.hideSystemUI ? 'true' : 'false'))
    lines.push('delete_empty_folders=' + (config.deleteEmptyFolders ? 'true' : 'false'))
    lines.push('allow_photo_gestures=' + (config.allowPhotoGestures ? 'true' : 'false'))
    lines.push('allow_video_gestures=' + (config.allowVideoGestures ? 'true' : 'false'))
    lines.push('show_extended_details=' + (config.showExtendedDetails ? 'true' : 'false'))
    lines.push('hide_extended_details=' + (config.hideExtendedDetails ? 'true' : 'false'))
    lines.push('allow_instant_change=' + (config.allowInstantChange ? 'true' : 'false'))
    lines.push('bottom_actions=' + (config.bottomActions ? 'true' : 'false'))
    lines.push('show_recycle_bin_at_folders=' + (config.showRecycleBinAtFolders ? 'true' : 'false'))
    lines.push('show_recycle_bin_last=' + (config.showRecycleBinLast ? 'true' : 'false'))
    lines.push('allow_zooming_images=' + (config.allowZoomingImages ? 'true' : 'false'))
    lines.push('show_highest_quality=' + (config.showHighestQuality ? 'true' : 'false'))
    lines.push('allow_down_gesture=' + (config.allowDownGesture ? 'true' : 'false'))
    lines.push('group_direct_subfolders=' + (config.groupDirectSubfolders ? 'true' : 'false'))
    lines.push('show_widget_folder_name=' + (config.showWidgetFolderName ? 'true' : 'false'))
    lines.push('allow_one_to_one_zoom=' + (config.allowOneToOneZoom ? 'true' : 'false'))
    lines.push('allow_rotating_with_gestures=' + (config.allowRotatingWithGestures ? 'true' : 'false'))
    lines.push('show_notch=' + (config.showNotch ? 'true' : 'false'))
    lines.push('show_thumbnail_file_types=' + (config.showThumbnailFileTypes ? 'true' : 'false'))
    lines.push('mark_favorite_items=' + (config.markFavoriteItems ? 'true' : 'false'))
    lines.push('use_recycle_bin=' + (config.useRecycleBin ? 'true' : 'false'))
    lines.push('slideshow_include_videos=' + (config.slideshowIncludeVideos ? 'true' : 'false'))
    lines.push('slideshow_include_gifs=' + (config.slideshowIncludeGifs ? 'true' : 'false'))
    lines.push('slideshow_random_order=' + (config.slideshowRandomOrder ? 'true' : 'false'))
    lines.push('slideshow_move_backwards=' + (config.slideshowMoveBackwards ? 'true' : 'false'))
    lines.push('slideshow_loop=' + (config.slideshowLoop ? 'true' : 'false'))
    lines.push('slideshow_start_on_enter=' + (config.slideshowStartOnEnter ? 'true' : 'false'))
    lines.push('search_all_files_by_default=' + (config.searchAllFilesByDefault ? 'true' : 'false'))
    lines.push('avoid_showing_all_files_prompt=' + (config.avoidShowingAllFilesPrompt ? 'true' : 'false'))
    lines.push('limit_folder_title=' + (config.limitFolderTitle ? 'true' : 'false'))

    // Number (integer) settings
    lines.push('directory_sorting=' + config.directorySorting.toString())
    lines.push('filter_media=' + config.filterMedia.toString())
    lines.push('dir_column_cnt=' + config.dirColumnCnt.toString())
    lines.push('dir_landscape_column_cnt=' + config.dirLandscapeColumnCnt.toString())
    lines.push('media_column_cnt=' + config.mediaColumnCnt.toString())
    lines.push('media_landscape_column_cnt=' + config.mediaLandscapeColumnCnt.toString())
    lines.push('screen_rotation=' + config.screenRotation.toString())
    lines.push('extended_details=' + config.extendedDetails.toString())
    lines.push('visible_bottom_actions=' + config.visibleBottomActions.toString())
    lines.push('group_by=' + config.groupBy.toString())
    lines.push('slideshow_interval=' + config.slideshowInterval.toString())
    lines.push('slideshow_animation=' + config.slideshowAnimation.toString())
    lines.push('last_editor_crop_aspect_ratio=' + config.lastEditorCropAspectRatio.toString())
    lines.push('last_bin_check=' + config.lastBinCheck.toString())
    lines.push('file_loading_priority=' + config.fileLoadingPriority.toString())
    lines.push('folder_thumbnail_style=' + config.folderThumbnailStyle.toString())
    lines.push('folder_media_count=' + config.folderMediaCount.toString())
    lines.push('thumbnail_spacing=' + config.thumbnailSpacing.toString())
    lines.push('file_rounded_corners=' + config.fileRoundedCorners.toString())
    lines.push('view_type_folders=' + config.viewTypeFolders.toString())
    lines.push('view_type_files=' + config.viewTypeFiles.toString())

    // Float settings
    lines.push('last_editor_crop_other_aspect_ratio_x=' + config.lastEditorCropOtherAspectRatioX.toString())
    lines.push('last_editor_crop_other_aspect_ratio_y=' + config.lastEditorCropOtherAspectRatioY.toString())
    lines.push('editor_brush_hardness=' + config.editorBrushHardness.toString())
    lines.push('editor_brush_size=' + config.editorBrushSize.toString())

    // Color settings (stored as number)
    lines.push('last_editor_draw_color=' + config.lastEditorDrawColor.toString())
    lines.push('editor_brush_color=' + config.editorBrushColor.toString())

    // String settings
    lines.push('default_folder=' + config.defaultFolder)
    lines.push('last_filepicker_path=' + config.lastFilepickerPath)
    lines.push('last_copy_path=' + config.lastCopyPath)
    lines.push('temp_folder_path=' + config.tempFolderPath)
    lines.push('album_covers=' + config.albumCovers)
    lines.push('custom_folders_order=' + config.customFoldersOrder)
    lines.push('last_exported_favorites_folder=' + config.lastExportedFavoritesFolder)

    // Set<string> settings (serialized as JSON arrays)
    lines.push('pinned_folders=' + JSON.stringify(Array.from(config.pinnedFolders)))
    lines.push('excluded_folders=' + JSON.stringify(Array.from(config.excludedFolders)))
    lines.push('included_folders=' + JSON.stringify(Array.from(config.includedFolders)))
    lines.push('ever_shown_folders=' + JSON.stringify(Array.from(config.everShownFolders)))

    return lines.join('\n')
  }

  static importSettings(content: string): void {
    const config: ConfigManager = ConfigManager.getInstance()
    const lines: string[] = content.split('\n')
    for (let i: number = 0; i < lines.length; i++) {
      const line: string = lines[i]
      const eqIdx: number = line.indexOf('=')
      if (eqIdx < 0) {
        continue
      }
      const key: string = line.substring(0, eqIdx).trim()
      const value: string = line.substring(eqIdx + 1).trim()

      switch (key) {
        // Boolean settings
        case 'show_hidden_media':
          config.showHiddenMedia = value === 'true'
          break
        case 'temporarily_show_hidden':
          config.temporarilyShowHidden = value === 'true'
          break
        case 'temporarily_show_excluded':
          config.temporarilyShowExcluded = value === 'true'
          break
        case 'autoplay_videos':
          config.autoplayVideos = value === 'true'
          break
        case 'remember_last_video_position':
          config.rememberLastVideoPosition = value === 'true'
          break
        case 'loop_videos':
          config.loopVideos = value === 'true'
          break
        case 'open_videos_on_separate_screen':
          config.openVideosOnSeparateScreen = value === 'true'
          break
        case 'animate_gifs':
          config.animateGifs = value === 'true'
          break
        case 'max_brightness':
          config.maxBrightness = value === 'true'
          break
        case 'crop_thumbnails':
          config.cropThumbnails = value === 'true'
          break
        case 'show_thumbnail_video_duration':
          config.showThumbnailVideoDuration = value === 'true'
          break
        case 'display_file_names':
          config.displayFileNames = value === 'true'
          break
        case 'black_background':
          config.blackBackground = value === 'true'
          break
        case 'show_all':
          config.showAll = value === 'true'
          break
        case 'hide_system_ui':
          config.hideSystemUI = value === 'true'
          break
        case 'delete_empty_folders':
          config.deleteEmptyFolders = value === 'true'
          break
        case 'allow_photo_gestures':
          config.allowPhotoGestures = value === 'true'
          break
        case 'allow_video_gestures':
          config.allowVideoGestures = value === 'true'
          break
        case 'show_extended_details':
          config.showExtendedDetails = value === 'true'
          break
        case 'hide_extended_details':
          config.hideExtendedDetails = value === 'true'
          break
        case 'allow_instant_change':
          config.allowInstantChange = value === 'true'
          break
        case 'bottom_actions':
          config.bottomActions = value === 'true'
          break
        case 'show_recycle_bin_at_folders':
          config.showRecycleBinAtFolders = value === 'true'
          break
        case 'show_recycle_bin_last':
          config.showRecycleBinLast = value === 'true'
          break
        case 'allow_zooming_images':
          config.allowZoomingImages = value === 'true'
          break
        case 'show_highest_quality':
          config.showHighestQuality = value === 'true'
          break
        case 'allow_down_gesture':
          config.allowDownGesture = value === 'true'
          break
        case 'group_direct_subfolders':
          config.groupDirectSubfolders = value === 'true'
          break
        case 'show_widget_folder_name':
          config.showWidgetFolderName = value === 'true'
          break
        case 'allow_one_to_one_zoom':
          config.allowOneToOneZoom = value === 'true'
          break
        case 'allow_rotating_with_gestures':
          config.allowRotatingWithGestures = value === 'true'
          break
        case 'show_notch':
          config.showNotch = value === 'true'
          break
        case 'show_thumbnail_file_types':
          config.showThumbnailFileTypes = value === 'true'
          break
        case 'mark_favorite_items':
          config.markFavoriteItems = value === 'true'
          break
        case 'use_recycle_bin':
          config.useRecycleBin = value === 'true'
          break
        case 'slideshow_include_videos':
          config.slideshowIncludeVideos = value === 'true'
          break
        case 'slideshow_include_gifs':
          config.slideshowIncludeGifs = value === 'true'
          break
        case 'slideshow_random_order':
          config.slideshowRandomOrder = value === 'true'
          break
        case 'slideshow_move_backwards':
          config.slideshowMoveBackwards = value === 'true'
          break
        case 'slideshow_loop':
          config.slideshowLoop = value === 'true'
          break
        case 'slideshow_start_on_enter':
          config.slideshowStartOnEnter = value === 'true'
          break
        case 'search_all_files_by_default':
          config.searchAllFilesByDefault = value === 'true'
          break
        case 'avoid_showing_all_files_prompt':
          config.avoidShowingAllFilesPrompt = value === 'true'
          break
        case 'limit_folder_title':
          config.limitFolderTitle = value === 'true'
          break

        // Number (integer) settings
        case 'directory_sorting':
          config.directorySorting = parseInt(value)
          break
        case 'filter_media':
          config.filterMedia = parseInt(value)
          break
        case 'dir_column_cnt':
          config.dirColumnCnt = parseInt(value)
          break
        case 'dir_landscape_column_cnt':
          config.dirLandscapeColumnCnt = parseInt(value)
          break
        case 'media_column_cnt':
          config.mediaColumnCnt = parseInt(value)
          break
        case 'media_landscape_column_cnt':
          config.mediaLandscapeColumnCnt = parseInt(value)
          break
        case 'screen_rotation':
          config.screenRotation = parseInt(value)
          break
        case 'extended_details':
          config.extendedDetails = parseInt(value)
          break
        case 'visible_bottom_actions':
          config.visibleBottomActions = parseInt(value)
          break
        case 'group_by':
          config.groupBy = parseInt(value)
          break
        case 'slideshow_interval':
          config.slideshowInterval = parseInt(value)
          break
        case 'slideshow_animation':
          config.slideshowAnimation = parseInt(value)
          break
        case 'last_editor_crop_aspect_ratio':
          config.lastEditorCropAspectRatio = parseInt(value)
          break
        case 'last_bin_check':
          config.lastBinCheck = parseInt(value)
          break
        case 'file_loading_priority':
          config.fileLoadingPriority = parseInt(value)
          break
        case 'folder_thumbnail_style':
          config.folderThumbnailStyle = parseInt(value)
          break
        case 'folder_media_count':
          config.folderMediaCount = parseInt(value)
          break
        case 'thumbnail_spacing':
          config.thumbnailSpacing = parseInt(value)
          break
        case 'file_rounded_corners':
          config.fileRoundedCorners = parseInt(value)
          break
        case 'view_type_folders':
          config.viewTypeFolders = parseInt(value)
          break
        case 'view_type_files':
          config.viewTypeFiles = parseInt(value)
          break

        // Float settings
        case 'last_editor_crop_other_aspect_ratio_x':
          config.lastEditorCropOtherAspectRatioX = parseFloat(value)
          break
        case 'last_editor_crop_other_aspect_ratio_y':
          config.lastEditorCropOtherAspectRatioY = parseFloat(value)
          break
        case 'editor_brush_hardness':
          config.editorBrushHardness = parseFloat(value)
          break
        case 'editor_brush_size':
          config.editorBrushSize = parseFloat(value)
          break

        // Color settings (stored as number)
        case 'last_editor_draw_color':
          config.lastEditorDrawColor = parseInt(value)
          break
        case 'editor_brush_color':
          config.editorBrushColor = parseInt(value)
          break

        // String settings
        case 'default_folder':
          config.defaultFolder = value
          break
        case 'last_filepicker_path':
          config.lastFilepickerPath = value
          break
        case 'last_copy_path':
          config.lastCopyPath = value
          break
        case 'temp_folder_path':
          config.tempFolderPath = value
          break
        case 'album_covers':
          config.albumCovers = value
          break
        case 'custom_folders_order':
          config.customFoldersOrder = value
          break
        case 'last_exported_favorites_folder':
          config.lastExportedFavoritesFolder = value
          break

        // Set<string> settings (JSON arrays)
        case 'pinned_folders':
          try {
            const pinnedArr: string[] = JSON.parse(value) as string[]
            config.pinnedFolders = new Set<string>(pinnedArr)
          } catch (e) {
            // skip malformed data
          }
          break
        case 'excluded_folders':
          try {
            const excludedArr: string[] = JSON.parse(value) as string[]
            config.excludedFolders = new Set<string>(excludedArr)
          } catch (e) {
            // skip malformed data
          }
          break
        case 'included_folders':
          try {
            const includedArr: string[] = JSON.parse(value) as string[]
            config.includedFolders = new Set<string>(includedArr)
          } catch (e) {
            // skip malformed data
          }
          break
        case 'ever_shown_folders':
          try {
            const everShownArr: string[] = JSON.parse(value) as string[]
            config.everShownFolders = new Set<string>(everShownArr)
          } catch (e) {
            // skip malformed data
          }
          break
        default:
          // Unknown key, skip
          break
      }
    }
  }
}

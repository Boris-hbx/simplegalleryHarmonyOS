// =============================================================================
// ConfigManager.ets — Singleton preferences wrapper for Simple Gallery (HarmonyOS)
// Ported from Android Config.kt
// =============================================================================

import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { AlbumCover } from '../common/models/AlbumCover';
import {
  DIRECTORY_SORT_ORDER,
  GROUP_FOLDER_PREFIX,
  VIEW_TYPE_PREFIX,
  SHOW_HIDDEN_MEDIA,
  TEMPORARILY_SHOW_HIDDEN,
  TEMPORARILY_SHOW_EXCLUDED,
  AUTOPLAY_VIDEOS,
  REMEMBER_LAST_VIDEO_POSITION,
  LOOP_VIDEOS,
  OPEN_VIDEOS_ON_SEPARATE_SCREEN,
  ANIMATE_GIFS,
  MAX_BRIGHTNESS,
  CROP_THUMBNAILS,
  SHOW_THUMBNAIL_VIDEO_DURATION,
  SCREEN_ROTATION,
  DISPLAY_FILE_NAMES,
  BLACK_BACKGROUND,
  PINNED_FOLDERS,
  FILTER_MEDIA,
  DEFAULT_FOLDER,
  DIR_COLUMN_CNT,
  DIR_LANDSCAPE_COLUMN_CNT,
  MEDIA_COLUMN_CNT,
  MEDIA_LANDSCAPE_COLUMN_CNT,
  SHOW_ALL,
  EXCLUDED_FOLDERS,
  INCLUDED_FOLDERS,
  ALBUM_COVERS,
  HIDE_SYSTEM_UI,
  DELETE_EMPTY_FOLDERS,
  ALLOW_PHOTO_GESTURES,
  ALLOW_VIDEO_GESTURES,
  TEMP_FOLDER_PATH,
  VIEW_TYPE_FOLDERS,
  VIEW_TYPE_FILES,
  SHOW_EXTENDED_DETAILS,
  EXTENDED_DETAILS,
  HIDE_EXTENDED_DETAILS,
  ALLOW_INSTANT_CHANGE,
  LAST_FILEPICKER_PATH,
  LAST_COPY_PATH,
  BOTTOM_ACTIONS,
  LAST_VIDEO_POSITION_PREFIX,
  VISIBLE_BOTTOM_ACTIONS,
  USE_RECYCLE_BIN,
  GROUP_BY,
  EVER_SHOWN_FOLDERS,
  SHOW_RECYCLE_BIN_AT_FOLDERS,
  SHOW_RECYCLE_BIN_LAST,
  ALLOW_ZOOMING_IMAGES,
  LAST_BIN_CHECK,
  SHOW_HIGHEST_QUALITY,
  ALLOW_DOWN_GESTURE,
  LAST_EDITOR_CROP_ASPECT_RATIO,
  LAST_EDITOR_CROP_OTHER_ASPECT_RATIO_X,
  LAST_EDITOR_CROP_OTHER_ASPECT_RATIO_Y,
  GROUP_DIRECT_SUBFOLDERS,
  SHOW_WIDGET_FOLDER_NAME,
  ALLOW_ONE_TO_ONE_ZOOM,
  ALLOW_ROTATING_WITH_GESTURES,
  LAST_EDITOR_DRAW_COLOR,
  SHOW_NOTCH,
  FILE_LOADING_PRIORITY,
  SHOW_THUMBNAIL_FILE_TYPES,
  MARK_FAVORITE_ITEMS,
  EDITOR_BRUSH_COLOR,
  EDITOR_BRUSH_HARDNESS,
  EDITOR_BRUSH_SIZE,
  FOLDER_THUMBNAIL_STYLE,
  FOLDER_MEDIA_COUNT,
  LIMIT_FOLDER_TITLE,
  THUMBNAIL_SPACING,
  FILE_ROUNDED_CORNERS,
  CUSTOM_FOLDERS_ORDER,
  AVOID_SHOWING_ALL_FILES_PROMPT,
  SEARCH_ALL_FILES_BY_DEFAULT,
  LAST_EXPORTED_FAVORITES_FOLDER,
  SLIDESHOW_INTERVAL,
  SLIDESHOW_INCLUDE_VIDEOS,
  SLIDESHOW_INCLUDE_GIFS,
  SLIDESHOW_RANDOM_ORDER,
  SLIDESHOW_MOVE_BACKWARDS,
  SLIDESHOW_ANIMATION,
  SLIDESHOW_LOOP,
  SLIDESHOW_START_ON_ENTER,
  SLIDESHOW_DEFAULT_INTERVAL,
  SLIDESHOW_ANIMATION_SLIDE,
  RECYCLE_BIN,
  SORT_BY_DATE_MODIFIED,
  SORT_DESCENDING,
  ROTATE_BY_SYSTEM_SETTING,
  PRIORITY_SPEED,
  EXT_RESOLUTION,
  EXT_LAST_MODIFIED,
  EXT_EXIF_PROPERTIES,
  GROUP_BY_NONE,
  GROUP_BY_FOLDER,
  SHOW_ALL as SHOW_ALL_KEY,
  DEFAULT_BOTTOM_ACTIONS,
  ASPECT_RATIO_FREE,
  VIEW_TYPE_GRID,
  FOLDER_STYLE_ROUNDED_CORNERS,
  FOLDER_MEDIA_CNT_LINE,
  ROUNDED_CORNERS_BIG,
  getDefaultFileFilter
} from '../common/constants/Constants';

const STORE_NAME: string = 'gallery_config';

export class ConfigManager {
  private static instance: ConfigManager | null = null;
  private prefs: preferences.Preferences | null = null;

  private constructor() {
  }

  static async initialize(context: Context): Promise<void> {
    if (ConfigManager.instance !== null) {
      return;
    }
    try {
      const mgr: ConfigManager = new ConfigManager();
      mgr.prefs = await preferences.getPreferences(context, STORE_NAME);
      ConfigManager.instance = mgr;
    } catch (e) {
      throw new Error('Failed to initialize ConfigManager: ' + (e as Error).message);
    }
  }

  static getInstance(): ConfigManager {
    if (ConfigManager.instance === null) {
      throw new Error('ConfigManager not initialized. Call initialize(context) first.');
    }
    return ConfigManager.instance;
  }

  static destroyInstance(): void {
    ConfigManager.instance = null;
  }

  // ===========================================================================
  // Boolean properties
  // ===========================================================================

  get showHiddenMedia(): boolean {
    return this.prefs!.getSync(SHOW_HIDDEN_MEDIA, false) as boolean;
  }

  set showHiddenMedia(value: boolean) {
    this.prefs!.putSync(SHOW_HIDDEN_MEDIA, value);
    this.prefs!.flush();
  }

  get temporarilyShowHidden(): boolean {
    return this.prefs!.getSync(TEMPORARILY_SHOW_HIDDEN, false) as boolean;
  }

  set temporarilyShowHidden(value: boolean) {
    this.prefs!.putSync(TEMPORARILY_SHOW_HIDDEN, value);
    this.prefs!.flush();
  }

  get temporarilyShowExcluded(): boolean {
    return this.prefs!.getSync(TEMPORARILY_SHOW_EXCLUDED, false) as boolean;
  }

  set temporarilyShowExcluded(value: boolean) {
    this.prefs!.putSync(TEMPORARILY_SHOW_EXCLUDED, value);
    this.prefs!.flush();
  }

  get autoplayVideos(): boolean {
    return this.prefs!.getSync(AUTOPLAY_VIDEOS, false) as boolean;
  }

  set autoplayVideos(value: boolean) {
    this.prefs!.putSync(AUTOPLAY_VIDEOS, value);
    this.prefs!.flush();
  }

  get rememberLastVideoPosition(): boolean {
    return this.prefs!.getSync(REMEMBER_LAST_VIDEO_POSITION, false) as boolean;
  }

  set rememberLastVideoPosition(value: boolean) {
    this.prefs!.putSync(REMEMBER_LAST_VIDEO_POSITION, value);
    this.prefs!.flush();
  }

  get loopVideos(): boolean {
    return this.prefs!.getSync(LOOP_VIDEOS, false) as boolean;
  }

  set loopVideos(value: boolean) {
    this.prefs!.putSync(LOOP_VIDEOS, value);
    this.prefs!.flush();
  }

  get openVideosOnSeparateScreen(): boolean {
    return this.prefs!.getSync(OPEN_VIDEOS_ON_SEPARATE_SCREEN, false) as boolean;
  }

  set openVideosOnSeparateScreen(value: boolean) {
    this.prefs!.putSync(OPEN_VIDEOS_ON_SEPARATE_SCREEN, value);
    this.prefs!.flush();
  }

  get animateGifs(): boolean {
    return this.prefs!.getSync(ANIMATE_GIFS, false) as boolean;
  }

  set animateGifs(value: boolean) {
    this.prefs!.putSync(ANIMATE_GIFS, value);
    this.prefs!.flush();
  }

  get maxBrightness(): boolean {
    return this.prefs!.getSync(MAX_BRIGHTNESS, false) as boolean;
  }

  set maxBrightness(value: boolean) {
    this.prefs!.putSync(MAX_BRIGHTNESS, value);
    this.prefs!.flush();
  }

  get cropThumbnails(): boolean {
    return this.prefs!.getSync(CROP_THUMBNAILS, true) as boolean;
  }

  set cropThumbnails(value: boolean) {
    this.prefs!.putSync(CROP_THUMBNAILS, value);
    this.prefs!.flush();
  }

  get showThumbnailVideoDuration(): boolean {
    return this.prefs!.getSync(SHOW_THUMBNAIL_VIDEO_DURATION, false) as boolean;
  }

  set showThumbnailVideoDuration(value: boolean) {
    this.prefs!.putSync(SHOW_THUMBNAIL_VIDEO_DURATION, value);
    this.prefs!.flush();
  }

  get displayFileNames(): boolean {
    return this.prefs!.getSync(DISPLAY_FILE_NAMES, false) as boolean;
  }

  set displayFileNames(value: boolean) {
    this.prefs!.putSync(DISPLAY_FILE_NAMES, value);
    this.prefs!.flush();
  }

  get blackBackground(): boolean {
    return this.prefs!.getSync(BLACK_BACKGROUND, false) as boolean;
  }

  set blackBackground(value: boolean) {
    this.prefs!.putSync(BLACK_BACKGROUND, value);
    this.prefs!.flush();
  }

  get showAll(): boolean {
    return this.prefs!.getSync(SHOW_ALL, false) as boolean;
  }

  set showAll(value: boolean) {
    this.prefs!.putSync(SHOW_ALL, value);
    this.prefs!.flush();
  }

  get hideSystemUI(): boolean {
    return this.prefs!.getSync(HIDE_SYSTEM_UI, false) as boolean;
  }

  set hideSystemUI(value: boolean) {
    this.prefs!.putSync(HIDE_SYSTEM_UI, value);
    this.prefs!.flush();
  }

  get deleteEmptyFolders(): boolean {
    return this.prefs!.getSync(DELETE_EMPTY_FOLDERS, false) as boolean;
  }

  set deleteEmptyFolders(value: boolean) {
    this.prefs!.putSync(DELETE_EMPTY_FOLDERS, value);
    this.prefs!.flush();
  }

  get allowPhotoGestures(): boolean {
    return this.prefs!.getSync(ALLOW_PHOTO_GESTURES, false) as boolean;
  }

  set allowPhotoGestures(value: boolean) {
    this.prefs!.putSync(ALLOW_PHOTO_GESTURES, value);
    this.prefs!.flush();
  }

  get allowVideoGestures(): boolean {
    return this.prefs!.getSync(ALLOW_VIDEO_GESTURES, true) as boolean;
  }

  set allowVideoGestures(value: boolean) {
    this.prefs!.putSync(ALLOW_VIDEO_GESTURES, value);
    this.prefs!.flush();
  }

  get showExtendedDetails(): boolean {
    return this.prefs!.getSync(SHOW_EXTENDED_DETAILS, false) as boolean;
  }

  set showExtendedDetails(value: boolean) {
    this.prefs!.putSync(SHOW_EXTENDED_DETAILS, value);
    this.prefs!.flush();
  }

  get hideExtendedDetails(): boolean {
    return this.prefs!.getSync(HIDE_EXTENDED_DETAILS, false) as boolean;
  }

  set hideExtendedDetails(value: boolean) {
    this.prefs!.putSync(HIDE_EXTENDED_DETAILS, value);
    this.prefs!.flush();
  }

  get allowInstantChange(): boolean {
    return this.prefs!.getSync(ALLOW_INSTANT_CHANGE, false) as boolean;
  }

  set allowInstantChange(value: boolean) {
    this.prefs!.putSync(ALLOW_INSTANT_CHANGE, value);
    this.prefs!.flush();
  }

  get bottomActions(): boolean {
    return this.prefs!.getSync(BOTTOM_ACTIONS, true) as boolean;
  }

  set bottomActions(value: boolean) {
    this.prefs!.putSync(BOTTOM_ACTIONS, value);
    this.prefs!.flush();
  }

  get showRecycleBinAtFolders(): boolean {
    return this.prefs!.getSync(SHOW_RECYCLE_BIN_AT_FOLDERS, true) as boolean;
  }

  set showRecycleBinAtFolders(value: boolean) {
    this.prefs!.putSync(SHOW_RECYCLE_BIN_AT_FOLDERS, value);
    this.prefs!.flush();
  }

  get showRecycleBinLast(): boolean {
    return this.prefs!.getSync(SHOW_RECYCLE_BIN_LAST, false) as boolean;
  }

  set showRecycleBinLast(value: boolean) {
    this.prefs!.putSync(SHOW_RECYCLE_BIN_LAST, value);
    this.prefs!.flush();
  }

  get allowZoomingImages(): boolean {
    return this.prefs!.getSync(ALLOW_ZOOMING_IMAGES, true) as boolean;
  }

  set allowZoomingImages(value: boolean) {
    this.prefs!.putSync(ALLOW_ZOOMING_IMAGES, value);
    this.prefs!.flush();
  }

  get showHighestQuality(): boolean {
    return this.prefs!.getSync(SHOW_HIGHEST_QUALITY, false) as boolean;
  }

  set showHighestQuality(value: boolean) {
    this.prefs!.putSync(SHOW_HIGHEST_QUALITY, value);
    this.prefs!.flush();
  }

  get allowDownGesture(): boolean {
    return this.prefs!.getSync(ALLOW_DOWN_GESTURE, true) as boolean;
  }

  set allowDownGesture(value: boolean) {
    this.prefs!.putSync(ALLOW_DOWN_GESTURE, value);
    this.prefs!.flush();
  }

  get groupDirectSubfolders(): boolean {
    return this.prefs!.getSync(GROUP_DIRECT_SUBFOLDERS, false) as boolean;
  }

  set groupDirectSubfolders(value: boolean) {
    this.prefs!.putSync(GROUP_DIRECT_SUBFOLDERS, value);
    this.prefs!.flush();
  }

  get showWidgetFolderName(): boolean {
    return this.prefs!.getSync(SHOW_WIDGET_FOLDER_NAME, true) as boolean;
  }

  set showWidgetFolderName(value: boolean) {
    this.prefs!.putSync(SHOW_WIDGET_FOLDER_NAME, value);
    this.prefs!.flush();
  }

  get allowOneToOneZoom(): boolean {
    return this.prefs!.getSync(ALLOW_ONE_TO_ONE_ZOOM, false) as boolean;
  }

  set allowOneToOneZoom(value: boolean) {
    this.prefs!.putSync(ALLOW_ONE_TO_ONE_ZOOM, value);
    this.prefs!.flush();
  }

  get allowRotatingWithGestures(): boolean {
    return this.prefs!.getSync(ALLOW_ROTATING_WITH_GESTURES, true) as boolean;
  }

  set allowRotatingWithGestures(value: boolean) {
    this.prefs!.putSync(ALLOW_ROTATING_WITH_GESTURES, value);
    this.prefs!.flush();
  }

  get showNotch(): boolean {
    return this.prefs!.getSync(SHOW_NOTCH, true) as boolean;
  }

  set showNotch(value: boolean) {
    this.prefs!.putSync(SHOW_NOTCH, value);
    this.prefs!.flush();
  }

  get showThumbnailFileTypes(): boolean {
    return this.prefs!.getSync(SHOW_THUMBNAIL_FILE_TYPES, true) as boolean;
  }

  set showThumbnailFileTypes(value: boolean) {
    this.prefs!.putSync(SHOW_THUMBNAIL_FILE_TYPES, value);
    this.prefs!.flush();
  }

  get markFavoriteItems(): boolean {
    return this.prefs!.getSync(MARK_FAVORITE_ITEMS, true) as boolean;
  }

  set markFavoriteItems(value: boolean) {
    this.prefs!.putSync(MARK_FAVORITE_ITEMS, value);
    this.prefs!.flush();
  }

  get useRecycleBin(): boolean {
    return this.prefs!.getSync(USE_RECYCLE_BIN, true) as boolean;
  }

  set useRecycleBin(value: boolean) {
    this.prefs!.putSync(USE_RECYCLE_BIN, value);
    this.prefs!.flush();
  }

  get slideshowIncludeVideos(): boolean {
    return this.prefs!.getSync(SLIDESHOW_INCLUDE_VIDEOS, false) as boolean;
  }

  set slideshowIncludeVideos(value: boolean) {
    this.prefs!.putSync(SLIDESHOW_INCLUDE_VIDEOS, value);
    this.prefs!.flush();
  }

  get slideshowIncludeGifs(): boolean {
    return this.prefs!.getSync(SLIDESHOW_INCLUDE_GIFS, false) as boolean;
  }

  set slideshowIncludeGifs(value: boolean) {
    this.prefs!.putSync(SLIDESHOW_INCLUDE_GIFS, value);
    this.prefs!.flush();
  }

  get slideshowRandomOrder(): boolean {
    return this.prefs!.getSync(SLIDESHOW_RANDOM_ORDER, false) as boolean;
  }

  set slideshowRandomOrder(value: boolean) {
    this.prefs!.putSync(SLIDESHOW_RANDOM_ORDER, value);
    this.prefs!.flush();
  }

  get slideshowMoveBackwards(): boolean {
    return this.prefs!.getSync(SLIDESHOW_MOVE_BACKWARDS, false) as boolean;
  }

  set slideshowMoveBackwards(value: boolean) {
    this.prefs!.putSync(SLIDESHOW_MOVE_BACKWARDS, value);
    this.prefs!.flush();
  }

  get slideshowLoop(): boolean {
    return this.prefs!.getSync(SLIDESHOW_LOOP, false) as boolean;
  }

  set slideshowLoop(value: boolean) {
    this.prefs!.putSync(SLIDESHOW_LOOP, value);
    this.prefs!.flush();
  }

  get slideshowStartOnEnter(): boolean {
    return this.prefs!.getSync(SLIDESHOW_START_ON_ENTER, false) as boolean;
  }

  set slideshowStartOnEnter(value: boolean) {
    this.prefs!.putSync(SLIDESHOW_START_ON_ENTER, value);
    this.prefs!.flush();
  }

  get searchAllFilesByDefault(): boolean {
    return this.prefs!.getSync(SEARCH_ALL_FILES_BY_DEFAULT, false) as boolean;
  }

  set searchAllFilesByDefault(value: boolean) {
    this.prefs!.putSync(SEARCH_ALL_FILES_BY_DEFAULT, value);
    this.prefs!.flush();
  }

  get avoidShowingAllFilesPrompt(): boolean {
    return this.prefs!.getSync(AVOID_SHOWING_ALL_FILES_PROMPT, false) as boolean;
  }

  set avoidShowingAllFilesPrompt(value: boolean) {
    this.prefs!.putSync(AVOID_SHOWING_ALL_FILES_PROMPT, value);
    this.prefs!.flush();
  }

  get limitFolderTitle(): boolean {
    return this.prefs!.getSync(LIMIT_FOLDER_TITLE, false) as boolean;
  }

  set limitFolderTitle(value: boolean) {
    this.prefs!.putSync(LIMIT_FOLDER_TITLE, value);
    this.prefs!.flush();
  }

  // ===========================================================================
  // Number properties
  // ===========================================================================

  get directorySorting(): number {
    return this.prefs!.getSync(DIRECTORY_SORT_ORDER, SORT_BY_DATE_MODIFIED | SORT_DESCENDING) as number;
  }

  set directorySorting(value: number) {
    this.prefs!.putSync(DIRECTORY_SORT_ORDER, value);
    this.prefs!.flush();
  }

  get filterMedia(): number {
    return this.prefs!.getSync(FILTER_MEDIA, getDefaultFileFilter()) as number;
  }

  set filterMedia(value: number) {
    this.prefs!.putSync(FILTER_MEDIA, value);
    this.prefs!.flush();
  }

  get dirColumnCnt(): number {
    return this.prefs!.getSync(DIR_COLUMN_CNT, 3) as number;
  }

  set dirColumnCnt(value: number) {
    this.prefs!.putSync(DIR_COLUMN_CNT, value);
    this.prefs!.flush();
  }

  get dirLandscapeColumnCnt(): number {
    return this.prefs!.getSync(DIR_LANDSCAPE_COLUMN_CNT, 5) as number;
  }

  set dirLandscapeColumnCnt(value: number) {
    this.prefs!.putSync(DIR_LANDSCAPE_COLUMN_CNT, value);
    this.prefs!.flush();
  }

  get mediaColumnCnt(): number {
    return this.prefs!.getSync(MEDIA_COLUMN_CNT, 3) as number;
  }

  set mediaColumnCnt(value: number) {
    this.prefs!.putSync(MEDIA_COLUMN_CNT, value);
    this.prefs!.flush();
  }

  get mediaLandscapeColumnCnt(): number {
    return this.prefs!.getSync(MEDIA_LANDSCAPE_COLUMN_CNT, 5) as number;
  }

  set mediaLandscapeColumnCnt(value: number) {
    this.prefs!.putSync(MEDIA_LANDSCAPE_COLUMN_CNT, value);
    this.prefs!.flush();
  }

  get screenRotation(): number {
    return this.prefs!.getSync(SCREEN_ROTATION, ROTATE_BY_SYSTEM_SETTING) as number;
  }

  set screenRotation(value: number) {
    this.prefs!.putSync(SCREEN_ROTATION, value);
    this.prefs!.flush();
  }

  get extendedDetails(): number {
    return this.prefs!.getSync(EXTENDED_DETAILS, EXT_RESOLUTION | EXT_LAST_MODIFIED | EXT_EXIF_PROPERTIES) as number;
  }

  set extendedDetails(value: number) {
    this.prefs!.putSync(EXTENDED_DETAILS, value);
    this.prefs!.flush();
  }

  get visibleBottomActions(): number {
    return this.prefs!.getSync(VISIBLE_BOTTOM_ACTIONS, DEFAULT_BOTTOM_ACTIONS) as number;
  }

  set visibleBottomActions(value: number) {
    this.prefs!.putSync(VISIBLE_BOTTOM_ACTIONS, value);
    this.prefs!.flush();
  }

  get groupBy(): number {
    return this.prefs!.getSync(GROUP_BY, GROUP_BY_NONE) as number;
  }

  set groupBy(value: number) {
    this.prefs!.putSync(GROUP_BY, value);
    this.prefs!.flush();
  }

  get slideshowInterval(): number {
    return this.prefs!.getSync(SLIDESHOW_INTERVAL, SLIDESHOW_DEFAULT_INTERVAL) as number;
  }

  set slideshowInterval(value: number) {
    this.prefs!.putSync(SLIDESHOW_INTERVAL, value);
    this.prefs!.flush();
  }

  get slideshowAnimation(): number {
    return this.prefs!.getSync(SLIDESHOW_ANIMATION, SLIDESHOW_ANIMATION_SLIDE) as number;
  }

  set slideshowAnimation(value: number) {
    this.prefs!.putSync(SLIDESHOW_ANIMATION, value);
    this.prefs!.flush();
  }

  get lastEditorCropAspectRatio(): number {
    return this.prefs!.getSync(LAST_EDITOR_CROP_ASPECT_RATIO, ASPECT_RATIO_FREE) as number;
  }

  set lastEditorCropAspectRatio(value: number) {
    this.prefs!.putSync(LAST_EDITOR_CROP_ASPECT_RATIO, value);
    this.prefs!.flush();
  }

  get lastBinCheck(): number {
    return this.prefs!.getSync(LAST_BIN_CHECK, 0) as number;
  }

  set lastBinCheck(value: number) {
    this.prefs!.putSync(LAST_BIN_CHECK, value);
    this.prefs!.flush();
  }

  get fileLoadingPriority(): number {
    return this.prefs!.getSync(FILE_LOADING_PRIORITY, PRIORITY_SPEED) as number;
  }

  set fileLoadingPriority(value: number) {
    this.prefs!.putSync(FILE_LOADING_PRIORITY, value);
    this.prefs!.flush();
  }

  get folderThumbnailStyle(): number {
    return this.prefs!.getSync(FOLDER_THUMBNAIL_STYLE, FOLDER_STYLE_ROUNDED_CORNERS) as number;
  }

  set folderThumbnailStyle(value: number) {
    this.prefs!.putSync(FOLDER_THUMBNAIL_STYLE, value);
    this.prefs!.flush();
  }

  get folderMediaCount(): number {
    return this.prefs!.getSync(FOLDER_MEDIA_COUNT, FOLDER_MEDIA_CNT_LINE) as number;
  }

  set folderMediaCount(value: number) {
    this.prefs!.putSync(FOLDER_MEDIA_COUNT, value);
    this.prefs!.flush();
  }

  get thumbnailSpacing(): number {
    return this.prefs!.getSync(THUMBNAIL_SPACING, 1) as number;
  }

  set thumbnailSpacing(value: number) {
    this.prefs!.putSync(THUMBNAIL_SPACING, value);
    this.prefs!.flush();
  }

  get fileRoundedCorners(): number {
    return this.prefs!.getSync(FILE_ROUNDED_CORNERS, ROUNDED_CORNERS_BIG) as number;
  }

  set fileRoundedCorners(value: number) {
    this.prefs!.putSync(FILE_ROUNDED_CORNERS, value);
    this.prefs!.flush();
  }

  // ===========================================================================
  // String properties
  // ===========================================================================

  get defaultFolder(): string {
    return this.prefs!.getSync(DEFAULT_FOLDER, '') as string;
  }

  set defaultFolder(value: string) {
    this.prefs!.putSync(DEFAULT_FOLDER, value);
    this.prefs!.flush();
  }

  get lastFilepickerPath(): string {
    return this.prefs!.getSync(LAST_FILEPICKER_PATH, '') as string;
  }

  set lastFilepickerPath(value: string) {
    this.prefs!.putSync(LAST_FILEPICKER_PATH, value);
    this.prefs!.flush();
  }

  get lastCopyPath(): string {
    return this.prefs!.getSync(LAST_COPY_PATH, '') as string;
  }

  set lastCopyPath(value: string) {
    this.prefs!.putSync(LAST_COPY_PATH, value);
    this.prefs!.flush();
  }

  get tempFolderPath(): string {
    return this.prefs!.getSync(TEMP_FOLDER_PATH, '') as string;
  }

  set tempFolderPath(value: string) {
    this.prefs!.putSync(TEMP_FOLDER_PATH, value);
    this.prefs!.flush();
  }

  get albumCovers(): string {
    return this.prefs!.getSync(ALBUM_COVERS, '') as string;
  }

  set albumCovers(value: string) {
    this.prefs!.putSync(ALBUM_COVERS, value);
    this.prefs!.flush();
  }

  get customFoldersOrder(): string {
    return this.prefs!.getSync(CUSTOM_FOLDERS_ORDER, '') as string;
  }

  set customFoldersOrder(value: string) {
    this.prefs!.putSync(CUSTOM_FOLDERS_ORDER, value);
    this.prefs!.flush();
  }

  get lastExportedFavoritesFolder(): string {
    return this.prefs!.getSync(LAST_EXPORTED_FAVORITES_FOLDER, '') as string;
  }

  set lastExportedFavoritesFolder(value: string) {
    this.prefs!.putSync(LAST_EXPORTED_FAVORITES_FOLDER, value);
    this.prefs!.flush();
  }

  // ===========================================================================
  // Float properties (stored as string for precision, since HarmonyOS
  // preferences does not have a native float type — numbers are doubles)
  // ===========================================================================

  get lastEditorCropOtherAspectRatioX(): number {
    return this.prefs!.getSync(LAST_EDITOR_CROP_OTHER_ASPECT_RATIO_X, 2.0) as number;
  }

  set lastEditorCropOtherAspectRatioX(value: number) {
    this.prefs!.putSync(LAST_EDITOR_CROP_OTHER_ASPECT_RATIO_X, value);
    this.prefs!.flush();
  }

  get lastEditorCropOtherAspectRatioY(): number {
    return this.prefs!.getSync(LAST_EDITOR_CROP_OTHER_ASPECT_RATIO_Y, 1.0) as number;
  }

  set lastEditorCropOtherAspectRatioY(value: number) {
    this.prefs!.putSync(LAST_EDITOR_CROP_OTHER_ASPECT_RATIO_Y, value);
    this.prefs!.flush();
  }

  get editorBrushHardness(): number {
    return this.prefs!.getSync(EDITOR_BRUSH_HARDNESS, 0.5) as number;
  }

  set editorBrushHardness(value: number) {
    this.prefs!.putSync(EDITOR_BRUSH_HARDNESS, value);
    this.prefs!.flush();
  }

  get editorBrushSize(): number {
    return this.prefs!.getSync(EDITOR_BRUSH_SIZE, 0.05) as number;
  }

  set editorBrushSize(value: number) {
    this.prefs!.putSync(EDITOR_BRUSH_SIZE, value);
    this.prefs!.flush();
  }

  // ===========================================================================
  // Color properties (stored as number)
  // ===========================================================================

  get lastEditorDrawColor(): number {
    return this.prefs!.getSync(LAST_EDITOR_DRAW_COLOR, 0xFF000000) as number;
  }

  set lastEditorDrawColor(value: number) {
    this.prefs!.putSync(LAST_EDITOR_DRAW_COLOR, value);
    this.prefs!.flush();
  }

  get editorBrushColor(): number {
    return this.prefs!.getSync(EDITOR_BRUSH_COLOR, 0xFF000000) as number;
  }

  set editorBrushColor(value: number) {
    this.prefs!.putSync(EDITOR_BRUSH_COLOR, value);
    this.prefs!.flush();
  }

  // ===========================================================================
  // View type properties with defaults
  // ===========================================================================

  get viewTypeFolders(): number {
    return this.prefs!.getSync(VIEW_TYPE_FOLDERS, VIEW_TYPE_GRID) as number;
  }

  set viewTypeFolders(value: number) {
    this.prefs!.putSync(VIEW_TYPE_FOLDERS, value);
    this.prefs!.flush();
  }

  get viewTypeFiles(): number {
    return this.prefs!.getSync(VIEW_TYPE_FILES, VIEW_TYPE_GRID) as number;
  }

  set viewTypeFiles(value: number) {
    this.prefs!.putSync(VIEW_TYPE_FILES, value);
    this.prefs!.flush();
  }

  // ===========================================================================
  // Computed property
  // ===========================================================================

  get shouldShowHidden(): boolean {
    return this.showHiddenMedia || this.temporarilyShowHidden;
  }

  // ===========================================================================
  // Set<string> properties (PIT-001: serialized via JSON.stringify/parse)
  // ===========================================================================

  get pinnedFolders(): Set<string> {
    const json: string = this.prefs!.getSync(PINNED_FOLDERS, '[]') as string;
    const arr: Array<string> = JSON.parse(json) as Array<string>;
    return new Set<string>(arr);
  }

  set pinnedFolders(value: Set<string>) {
    const arr: Array<string> = Array.from(value);
    this.prefs!.putSync(PINNED_FOLDERS, JSON.stringify(arr));
    this.prefs!.flush();
  }

  addPinnedFolders(paths: Set<string>): void {
    const current: Set<string> = this.pinnedFolders;
    const pathsArr: Array<string> = Array.from(paths);
    for (let i: number = 0; i < pathsArr.length; i++) {
      const p: string = pathsArr[i];
      if (p.length > 0) {
        current.add(p);
      }
    }
    this.pinnedFolders = current;
    if (paths.has(RECYCLE_BIN)) {
      this.showRecycleBinLast = false;
    }
  }

  removePinnedFolders(paths: Set<string>): void {
    const current: Set<string> = this.pinnedFolders;
    const pathsArr: Array<string> = Array.from(paths);
    for (let i: number = 0; i < pathsArr.length; i++) {
      current.delete(pathsArr[i]);
    }
    this.pinnedFolders = current;
  }

  get excludedFolders(): Set<string> {
    const json: string = this.prefs!.getSync(EXCLUDED_FOLDERS, '[]') as string;
    const arr: Array<string> = JSON.parse(json) as Array<string>;
    return new Set<string>(arr);
  }

  set excludedFolders(value: Set<string>) {
    const arr: Array<string> = Array.from(value);
    this.prefs!.putSync(EXCLUDED_FOLDERS, JSON.stringify(arr));
    this.prefs!.flush();
  }

  addExcludedFolders(paths: Set<string>): void {
    const current: Set<string> = this.excludedFolders;
    const pathsArr: Array<string> = Array.from(paths);
    for (let i: number = 0; i < pathsArr.length; i++) {
      const p: string = pathsArr[i];
      if (p.length > 0) {
        current.add(p);
      }
    }
    this.excludedFolders = current;
  }

  removeExcludedFolders(paths: Set<string>): void {
    const current: Set<string> = this.excludedFolders;
    const pathsArr: Array<string> = Array.from(paths);
    for (let i: number = 0; i < pathsArr.length; i++) {
      current.delete(pathsArr[i]);
    }
    this.excludedFolders = current;
  }

  get includedFolders(): Set<string> {
    const json: string = this.prefs!.getSync(INCLUDED_FOLDERS, '[]') as string;
    const arr: Array<string> = JSON.parse(json) as Array<string>;
    return new Set<string>(arr);
  }

  set includedFolders(value: Set<string>) {
    const arr: Array<string> = Array.from(value);
    this.prefs!.putSync(INCLUDED_FOLDERS, JSON.stringify(arr));
    this.prefs!.flush();
  }

  addIncludedFolders(paths: Set<string>): void {
    const current: Set<string> = this.includedFolders;
    const pathsArr: Array<string> = Array.from(paths);
    for (let i: number = 0; i < pathsArr.length; i++) {
      const p: string = pathsArr[i];
      if (p.length > 0) {
        current.add(p);
      }
    }
    this.includedFolders = current;
  }

  removeIncludedFolders(paths: Set<string>): void {
    const current: Set<string> = this.includedFolders;
    const pathsArr: Array<string> = Array.from(paths);
    for (let i: number = 0; i < pathsArr.length; i++) {
      current.delete(pathsArr[i]);
    }
    this.includedFolders = current;
  }

  get everShownFolders(): Set<string> {
    const json: string = this.prefs!.getSync(EVER_SHOWN_FOLDERS, '[]') as string;
    const arr: Array<string> = JSON.parse(json) as Array<string>;
    return new Set<string>(arr);
  }

  set everShownFolders(value: Set<string>) {
    const arr: Array<string> = Array.from(value);
    this.prefs!.putSync(EVER_SHOWN_FOLDERS, JSON.stringify(arr));
    this.prefs!.flush();
  }

  addEverShownFolders(paths: Set<string>): void {
    const current: Set<string> = this.everShownFolders;
    const pathsArr: Array<string> = Array.from(paths);
    for (let i: number = 0; i < pathsArr.length; i++) {
      const p: string = pathsArr[i];
      if (p.length > 0) {
        current.add(p);
      }
    }
    this.everShownFolders = current;
  }

  removeEverShownFolders(paths: Set<string>): void {
    const current: Set<string> = this.everShownFolders;
    const pathsArr: Array<string> = Array.from(paths);
    for (let i: number = 0; i < pathsArr.length; i++) {
      current.delete(pathsArr[i]);
    }
    this.everShownFolders = current;
  }

  // ===========================================================================
  // Special methods — path-prefixed keys
  // ===========================================================================

  saveFolderGrouping(path: string, value: number): void {
    if (path.length === 0) {
      this.groupBy = value;
    } else {
      try {
        this.prefs!.putSync(GROUP_FOLDER_PREFIX + path.toLowerCase(), value);
        this.prefs!.flush();
      } catch (e) {
        // Ignore preference write failure
      }
    }
  }

  getFolderGrouping(path: string): number {
    try {
      let result: number = this.prefs!.getSync(GROUP_FOLDER_PREFIX + path.toLowerCase(), this.groupBy) as number;
      if (path !== SHOW_ALL_KEY && (result & GROUP_BY_FOLDER) !== 0) {
        result = result - GROUP_BY_FOLDER + 1;
      }
      return result;
    } catch (e) {
      return this.groupBy;
    }
  }

  saveFolderViewType(path: string, value: number): void {
    if (path.length === 0) {
      this.viewTypeFiles = value;
    } else {
      try {
        this.prefs!.putSync(VIEW_TYPE_PREFIX + path.toLowerCase(), value);
        this.prefs!.flush();
      } catch (e) {
        // Ignore preference write failure
      }
    }
  }

  getFolderViewType(path: string): number {
    try {
      return this.prefs!.getSync(VIEW_TYPE_PREFIX + path.toLowerCase(), this.viewTypeFiles) as number;
    } catch (e) {
      return this.viewTypeFiles;
    }
  }

  // ===========================================================================
  // Last video position — keyed by hash
  // ===========================================================================

  saveLastVideoPosition(hash: string, position: number): void {
    if (hash.length > 0) {
      try {
        this.prefs!.putSync(LAST_VIDEO_POSITION_PREFIX + hash.toLowerCase(), position);
        this.prefs!.flush();
      } catch (e) {
        // Ignore preference write failure
      }
    }
  }

  getLastVideoPosition(hash: string): number {
    try {
      return this.prefs!.getSync(LAST_VIDEO_POSITION_PREFIX + hash.toLowerCase(), 0) as number;
    } catch (e) {
      return 0;
    }
  }

  // ===========================================================================
  // Album covers parsing
  // ===========================================================================

  parseAlbumCovers(): Array<AlbumCover> {
    const raw: string = this.albumCovers;
    if (raw.length === 0) {
      return new Array<AlbumCover>();
    }
    try {
      const parsed: Array<AlbumCover> = JSON.parse(raw) as Array<AlbumCover>;
      const result: Array<AlbumCover> = new Array<AlbumCover>();
      for (let i: number = 0; i < parsed.length; i++) {
        const item: AlbumCover = parsed[i];
        result.push(new AlbumCover(item.path, item.tmb));
      }
      return result;
    } catch (e) {
      return new Array<AlbumCover>();
    }
  }
}

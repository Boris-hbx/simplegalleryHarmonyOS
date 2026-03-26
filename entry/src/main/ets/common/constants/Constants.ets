// =============================================================================
// Constants.ets — All application constants for Simple Gallery (HarmonyOS)
// Ported from Android Constants.kt
// =============================================================================

// =============================================================================
// Shared Preferences Keys
// =============================================================================

export const DIRECTORY_SORT_ORDER: string = 'directory_sort_order'
export const GROUP_FOLDER_PREFIX: string = 'group_folder_'
export const VIEW_TYPE_PREFIX: string = 'view_type_folder_'
export const SHOW_HIDDEN_MEDIA: string = 'show_hidden_media'
export const TEMPORARILY_SHOW_HIDDEN: string = 'temporarily_show_hidden'
export const TEMPORARILY_SHOW_EXCLUDED: string = 'temporarily_show_excluded'
export const EXCLUDED_PASSWORD_PROTECTION: string = 'excluded_password_protection'
export const EXCLUDED_PASSWORD_HASH: string = 'excluded_password_hash'
export const EXCLUDED_PROTECTION_TYPE: string = 'excluded_protection_type'
export const IS_THIRD_PARTY_INTENT: string = 'is_third_party_intent'
export const AUTOPLAY_VIDEOS: string = 'autoplay_videos'
export const REMEMBER_LAST_VIDEO_POSITION: string = 'remember_last_video_position'
export const LOOP_VIDEOS: string = 'loop_videos'
export const OPEN_VIDEOS_ON_SEPARATE_SCREEN: string = 'open_videos_on_separate_screen'
export const ANIMATE_GIFS: string = 'animate_gifs'
export const MAX_BRIGHTNESS: string = 'max_brightness'
export const CROP_THUMBNAILS: string = 'crop_thumbnails'
export const SHOW_THUMBNAIL_VIDEO_DURATION: string = 'show_thumbnail_video_duration'
export const SCREEN_ROTATION: string = 'screen_rotation'
export const DISPLAY_FILE_NAMES: string = 'display_file_names'
export const BLACK_BACKGROUND: string = 'dark_background'
export const PINNED_FOLDERS: string = 'pinned_folders'
export const FILTER_MEDIA: string = 'filter_media'
export const DEFAULT_FOLDER: string = 'default_folder'
export const DIR_COLUMN_CNT: string = 'dir_column_cnt'
export const DIR_LANDSCAPE_COLUMN_CNT: string = 'dir_landscape_column_cnt'
export const DIR_HORIZONTAL_COLUMN_CNT: string = 'dir_horizontal_column_cnt'
export const DIR_LANDSCAPE_HORIZONTAL_COLUMN_CNT: string = 'dir_landscape_horizontal_column_cnt'
export const MEDIA_COLUMN_CNT: string = 'media_column_cnt'
export const MEDIA_LANDSCAPE_COLUMN_CNT: string = 'media_landscape_column_cnt'
export const MEDIA_HORIZONTAL_COLUMN_CNT: string = 'media_horizontal_column_cnt'
export const MEDIA_LANDSCAPE_HORIZONTAL_COLUMN_CNT: string = 'media_landscape_horizontal_column_cnt'
export const SHOW_ALL: string = 'show_all'
export const HIDE_FOLDER_TOOLTIP_SHOWN: string = 'hide_folder_tooltip_shown'
export const EXCLUDED_FOLDERS: string = 'excluded_folders'
export const INCLUDED_FOLDERS: string = 'included_folders'
export const ALBUM_COVERS: string = 'album_covers'
export const HIDE_SYSTEM_UI: string = 'hide_system_ui'
export const DELETE_EMPTY_FOLDERS: string = 'delete_empty_folders'
export const ALLOW_PHOTO_GESTURES: string = 'allow_photo_gestures'
export const ALLOW_VIDEO_GESTURES: string = 'allow_video_gestures'
export const TEMP_FOLDER_PATH: string = 'temp_folder_path'
export const VIEW_TYPE_FOLDERS: string = 'view_type_folders'
export const VIEW_TYPE_FILES: string = 'view_type_files'
export const SHOW_EXTENDED_DETAILS: string = 'show_extended_details'
export const EXTENDED_DETAILS: string = 'extended_details'
export const HIDE_EXTENDED_DETAILS: string = 'hide_extended_details'
export const ALLOW_INSTANT_CHANGE: string = 'allow_instant_change'
export const WAS_NEW_APP_SHOWN: string = 'was_new_app_shown_clock'
export const LAST_FILEPICKER_PATH: string = 'last_filepicker_path'
export const LAST_COPY_PATH: string = 'last_copy_path'
export const TEMP_SKIP_DELETE_CONFIRMATION: string = 'temp_skip_delete_confirmation'
export const TEMP_SKIP_RECYCLE_BIN: string = 'temp_skip_recycle_bin'
export const BOTTOM_ACTIONS: string = 'bottom_actions'
export const LAST_VIDEO_POSITION_PREFIX: string = 'last_video_position_'
export const VISIBLE_BOTTOM_ACTIONS: string = 'visible_bottom_actions'
export const WERE_FAVORITES_PINNED: string = 'were_favorites_pinned'
export const WAS_RECYCLE_BIN_PINNED: string = 'was_recycle_bin_pinned'
export const USE_RECYCLE_BIN: string = 'use_recycle_bin'
export const GROUP_BY: string = 'group_by'
export const EVER_SHOWN_FOLDERS: string = 'ever_shown_folders'
export const SHOW_RECYCLE_BIN_AT_FOLDERS: string = 'show_recycle_bin_at_folders'
export const SHOW_RECYCLE_BIN_LAST: string = 'show_recycle_bin_last'
export const ALLOW_ZOOMING_IMAGES: string = 'allow_zooming_images'
export const WAS_SVG_SHOWING_HANDLED: string = 'was_svg_showing_handled'
export const LAST_BIN_CHECK: string = 'last_bin_check'
export const SHOW_HIGHEST_QUALITY: string = 'show_highest_quality'
export const ALLOW_DOWN_GESTURE: string = 'allow_down_gesture'
export const LAST_EDITOR_CROP_ASPECT_RATIO: string = 'last_editor_crop_aspect_ratio'
export const LAST_EDITOR_CROP_OTHER_ASPECT_RATIO_X: string = 'last_editor_crop_other_aspect_ratio_x_2'
export const LAST_EDITOR_CROP_OTHER_ASPECT_RATIO_Y: string = 'last_editor_crop_other_aspect_ratio_y_2'
export const GROUP_DIRECT_SUBFOLDERS: string = 'group_direct_subfolders'
export const SHOW_WIDGET_FOLDER_NAME: string = 'show_widget_folder_name'
export const ALLOW_ONE_TO_ONE_ZOOM: string = 'allow_one_to_one_zoom'
export const ALLOW_ROTATING_WITH_GESTURES: string = 'allow_rotating_with_gestures'
export const LAST_EDITOR_DRAW_COLOR: string = 'last_editor_draw_color'
export const LAST_EDITOR_BRUSH_SIZE: string = 'last_editor_brush_size'
export const SHOW_NOTCH: string = 'show_notch'
export const FILE_LOADING_PRIORITY: string = 'file_loading_priority'
export const SPAM_FOLDERS_CHECKED: string = 'spam_folders_checked'
export const SHOW_THUMBNAIL_FILE_TYPES: string = 'show_thumbnail_file_types'
export const MARK_FAVORITE_ITEMS: string = 'mark_favorite_items'
export const EDITOR_BRUSH_COLOR: string = 'editor_brush_color'
export const EDITOR_BRUSH_HARDNESS: string = 'editor_brush_hardness'
export const EDITOR_BRUSH_SIZE: string = 'editor_brush_size'
export const WERE_FAVORITES_MIGRATED: string = 'were_favorites_migrated'
export const FOLDER_THUMBNAIL_STYLE: string = 'folder_thumbnail_style'
export const FOLDER_MEDIA_COUNT: string = 'folder_media_count'
export const LIMIT_FOLDER_TITLE: string = 'folder_limit_title'
export const THUMBNAIL_SPACING: string = 'thumbnail_spacing'
export const FILE_ROUNDED_CORNERS: string = 'file_rounded_corners'
export const CUSTOM_FOLDERS_ORDER: string = 'custom_folders_order'
export const AVOID_SHOWING_ALL_FILES_PROMPT: string = 'avoid_showing_all_files_prompt'
export const SEARCH_ALL_FILES_BY_DEFAULT: string = 'search_all_files_by_default'
export const LAST_EXPORTED_FAVORITES_FOLDER: string = 'last_exported_favorites_folder'

// =============================================================================
// Slideshow
// =============================================================================

export const SLIDESHOW_INTERVAL: string = 'slideshow_interval'
export const SLIDESHOW_INCLUDE_VIDEOS: string = 'slideshow_include_videos'
export const SLIDESHOW_INCLUDE_GIFS: string = 'slideshow_include_gifs'
export const SLIDESHOW_RANDOM_ORDER: string = 'slideshow_random_order'
export const SLIDESHOW_MOVE_BACKWARDS: string = 'slideshow_move_backwards'
export const SLIDESHOW_ANIMATION: string = 'slideshow_animation'
export const SLIDESHOW_LOOP: string = 'loop_slideshow'
export const SLIDESHOW_DEFAULT_INTERVAL: number = 5
export const SLIDESHOW_SLIDE_DURATION: number = 500
export const SLIDESHOW_FADE_DURATION: number = 1500
export const SLIDESHOW_START_ON_ENTER: string = 'slideshow_start_on_enter'
export const SLIDESHOW_ANIMATION_NONE: number = 0
export const SLIDESHOW_ANIMATION_SLIDE: number = 1
export const SLIDESHOW_ANIMATION_FADE: number = 2

// =============================================================================
// Special Paths
// =============================================================================

export const RECYCLE_BIN: string = 'recycle_bin'
export const SHOW_FAVORITES: string = 'show_favorites'
export const SHOW_RECYCLE_BIN: string = 'show_recycle_bin'
export const IS_IN_RECYCLE_BIN: string = 'is_in_recycle_bin'
export const SHOW_NEXT_ITEM: string = 'show_next_item'
export const SHOW_PREV_ITEM: string = 'show_prev_item'
export const GO_TO_NEXT_ITEM: string = 'go_to_next_item'
export const GO_TO_PREV_ITEM: string = 'go_to_prev_item'

// =============================================================================
// UI Constants
// =============================================================================

export const MAX_COLUMN_COUNT: number = 20
export const SHOW_TEMP_HIDDEN_DURATION: number = 300000
export const CLICK_MAX_DURATION: number = 150
export const CLICK_MAX_DISTANCE: number = 100
export const MAX_CLOSE_DOWN_GESTURE_DURATION: number = 300
export const DRAG_THRESHOLD: number = 8
export const MONTH_MILLISECONDS: number = 2592000000
export const MIN_SKIP_LENGTH: number = 2000
export const HIDE_SYSTEM_UI_DELAY: number = 500
export const MAX_PRINT_SIDE_SIZE: number = 4096
export const FAST_FORWARD_VIDEO_MS: number = 10000

// =============================================================================
// Intent / Navigation
// =============================================================================

export const DIRECTORY: string = 'directory'
export const MEDIUM: string = 'medium'
export const PATH: string = 'path'
export const GET_IMAGE_INTENT: string = 'get_image_intent'
export const GET_VIDEO_INTENT: string = 'get_video_intent'
export const GET_ANY_INTENT: string = 'get_any_intent'
export const SET_WALLPAPER_INTENT: string = 'set_wallpaper_intent'
export const IS_VIEW_INTENT: string = 'is_view_intent'
export const PICKED_PATHS: string = 'picked_paths'
export const SHOULD_INIT_FRAGMENT: string = 'should_init_fragment'
export const PORTRAIT_PATH: string = 'portrait_path'
export const SKIP_AUTHENTICATION: string = 'skip_authentication'

// =============================================================================
// Rotation
// =============================================================================

export const ROTATE_BY_SYSTEM_SETTING: number = 0
export const ROTATE_BY_DEVICE_ROTATION: number = 1
export const ROTATE_BY_ASPECT_RATIO: number = 2

// =============================================================================
// File Loading Priority
// =============================================================================

export const PRIORITY_SPEED: number = 0
export const PRIORITY_COMPROMISE: number = 1
export const PRIORITY_VALIDITY: number = 2

// =============================================================================
// Extended Details (bitmask)
// =============================================================================

export const EXT_NAME: number = 1
export const EXT_PATH: number = 2
export const EXT_SIZE: number = 4
export const EXT_RESOLUTION: number = 8
export const EXT_LAST_MODIFIED: number = 16
export const EXT_DATE_TAKEN: number = 32
export const EXT_CAMERA_MODEL: number = 64
export const EXT_EXIF_PROPERTIES: number = 128
export const EXT_DURATION: number = 256
export const EXT_ARTIST: number = 512
export const EXT_ALBUM: number = 1024
export const EXT_GPS: number = 2048

// =============================================================================
// Media Types (bitmask)
// =============================================================================

export const TYPE_IMAGES: number = 1
export const TYPE_VIDEOS: number = 2
export const TYPE_GIFS: number = 4
export const TYPE_RAWS: number = 8
export const TYPE_SVGS: number = 16
export const TYPE_PORTRAITS: number = 32

// =============================================================================
// Location
// =============================================================================

export const LOCATION_INTERNAL: number = 1
export const LOCATION_SD: number = 2
export const LOCATION_OTG: number = 3

// =============================================================================
// Group By (bitmask)
// =============================================================================

export const GROUP_BY_NONE: number = 1
export const GROUP_BY_LAST_MODIFIED_DAILY: number = 2
export const GROUP_BY_DATE_TAKEN_DAILY: number = 4
export const GROUP_BY_FILE_TYPE: number = 8
export const GROUP_BY_EXTENSION: number = 16
export const GROUP_BY_FOLDER: number = 32
export const GROUP_BY_LAST_MODIFIED_MONTHLY: number = 64
export const GROUP_BY_DATE_TAKEN_MONTHLY: number = 128
export const GROUP_DESCENDING: number = 1024
export const GROUP_SHOW_FILE_COUNT: number = 2048

// =============================================================================
// Bottom Actions (bitmask)
// =============================================================================

export const BOTTOM_ACTION_TOGGLE_FAVORITE: number = 1
export const BOTTOM_ACTION_EDIT: number = 2
export const BOTTOM_ACTION_SHARE: number = 4
export const BOTTOM_ACTION_DELETE: number = 8
export const BOTTOM_ACTION_ROTATE: number = 16
export const BOTTOM_ACTION_PROPERTIES: number = 32
export const BOTTOM_ACTION_CHANGE_ORIENTATION: number = 64
export const BOTTOM_ACTION_SLIDESHOW: number = 128
export const BOTTOM_ACTION_SHOW_ON_MAP: number = 256
export const BOTTOM_ACTION_TOGGLE_VISIBILITY: number = 512
export const BOTTOM_ACTION_RENAME: number = 1024
export const BOTTOM_ACTION_SET_AS: number = 2048
export const BOTTOM_ACTION_COPY: number = 4096
export const BOTTOM_ACTION_MOVE: number = 8192
export const BOTTOM_ACTION_RESIZE: number = 16384
export const DEFAULT_BOTTOM_ACTIONS: number = 15

// =============================================================================
// Aspect Ratios
// =============================================================================

export const ASPECT_RATIO_FREE: number = 0
export const ASPECT_RATIO_ONE_ONE: number = 1
export const ASPECT_RATIO_FOUR_THREE: number = 2
export const ASPECT_RATIO_SIXTEEN_NINE: number = 3
export const ASPECT_RATIO_OTHER: number = 4

// =============================================================================
// Tile DPI
// =============================================================================

export const LOW_TILE_DPI: number = 160
export const NORMAL_TILE_DPI: number = 220
export const WEIRD_TILE_DPI: number = 240
export const HIGH_TILE_DPI: number = 280

// =============================================================================
// Rounded Corners
// =============================================================================

export const ROUNDED_CORNERS_NONE: number = 1
export const ROUNDED_CORNERS_SMALL: number = 2
export const ROUNDED_CORNERS_BIG: number = 3

// =============================================================================
// Folder Media Count
// =============================================================================

export const FOLDER_MEDIA_CNT_LINE: number = 1
export const FOLDER_MEDIA_CNT_BRACKETS: number = 2
export const FOLDER_MEDIA_CNT_NONE: number = 3

// =============================================================================
// Folder Style
// =============================================================================

export const FOLDER_STYLE_SQUARE: number = 1
export const FOLDER_STYLE_ROUNDED_CORNERS: number = 2

// =============================================================================
// From Simple-Commons (needed locally)
// =============================================================================

export const SORT_BY_NAME: number = 1
export const SORT_BY_DATE_MODIFIED: number = 2
export const SORT_BY_SIZE: number = 4
export const SORT_BY_DATE_TAKEN: number = 8
export const SORT_BY_RANDOM: number = 512
export const SORT_BY_PATH: number = 1024
export const SORT_DESCENDING: number = 1048576
export const VIEW_TYPE_GRID: number = 1
export const VIEW_TYPE_LIST: number = 2
export const FAVORITES: string = 'favorites'
export const MONTH_SECONDS: number = 2592000
export const PROTECTION_PATTERN: number = 2

// =============================================================================
// Helper Functions
// =============================================================================

export function getDefaultFileFilter(): number {
  return TYPE_IMAGES | TYPE_VIDEOS | TYPE_GIFS | TYPE_RAWS | TYPE_SVGS
}

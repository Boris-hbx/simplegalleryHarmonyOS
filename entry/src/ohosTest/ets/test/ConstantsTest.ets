import { describe, it, expect } from '@ohos/hypium'
import {
  TYPE_IMAGES,
  TYPE_VIDEOS,
  TYPE_GIFS,
  TYPE_RAWS,
  TYPE_SVGS,
  TYPE_PORTRAITS,
  SORT_BY_NAME,
  SORT_BY_DATE_MODIFIED,
  SORT_BY_SIZE,
  SORT_BY_DATE_TAKEN,
  SORT_BY_RANDOM,
  SORT_BY_PATH,
  SORT_DESCENDING,
  GROUP_BY_NONE,
  GROUP_BY_LAST_MODIFIED_DAILY,
  GROUP_BY_DATE_TAKEN_DAILY,
  GROUP_BY_FILE_TYPE,
  GROUP_BY_EXTENSION,
  GROUP_BY_FOLDER,
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
  PRIORITY_VALIDITY,
  getDefaultFileFilter
} from '../../../main/ets/common/constants/Constants'

export default function ConstantsTest() {
  describe('ConstantsTest', () => {

    // ---- Media type bitmask values are unique and non-overlapping ----

    it('TYPE_IMAGES_value', 0, () => {
      expect(TYPE_IMAGES).assertEqual(1)
    })

    it('TYPE_VIDEOS_value', 0, () => {
      expect(TYPE_VIDEOS).assertEqual(2)
    })

    it('TYPE_GIFS_value', 0, () => {
      expect(TYPE_GIFS).assertEqual(4)
    })

    it('TYPE_RAWS_value', 0, () => {
      expect(TYPE_RAWS).assertEqual(8)
    })

    it('TYPE_SVGS_value', 0, () => {
      expect(TYPE_SVGS).assertEqual(16)
    })

    it('TYPE_PORTRAITS_value', 0, () => {
      expect(TYPE_PORTRAITS).assertEqual(32)
    })

    it('media_types_no_overlap', 0, () => {
      const all: number = TYPE_IMAGES | TYPE_VIDEOS | TYPE_GIFS | TYPE_RAWS | TYPE_SVGS | TYPE_PORTRAITS
      // If no overlap, sum of individual values equals OR result
      const sum: number = TYPE_IMAGES + TYPE_VIDEOS + TYPE_GIFS + TYPE_RAWS + TYPE_SVGS + TYPE_PORTRAITS
      expect(all).assertEqual(sum)
    })

    // ---- Sort constants are unique bitmask values ----

    it('SORT_BY_NAME_value', 0, () => {
      expect(SORT_BY_NAME).assertEqual(1)
    })

    it('SORT_BY_DATE_MODIFIED_value', 0, () => {
      expect(SORT_BY_DATE_MODIFIED).assertEqual(2)
    })

    it('SORT_BY_SIZE_value', 0, () => {
      expect(SORT_BY_SIZE).assertEqual(4)
    })

    it('SORT_BY_DATE_TAKEN_value', 0, () => {
      expect(SORT_BY_DATE_TAKEN).assertEqual(8)
    })

    it('SORT_DESCENDING_value', 0, () => {
      expect(SORT_DESCENDING).assertEqual(1048576)
    })

    it('sort_types_no_overlap_with_descending', 0, () => {
      // SORT_DESCENDING should not overlap with any sort type
      expect((SORT_BY_NAME & SORT_DESCENDING)).assertEqual(0)
      expect((SORT_BY_SIZE & SORT_DESCENDING)).assertEqual(0)
      expect((SORT_BY_DATE_MODIFIED & SORT_DESCENDING)).assertEqual(0)
    })

    // ---- Group by constants ----

    it('GROUP_BY_NONE_value', 0, () => {
      expect(GROUP_BY_NONE).assertEqual(1)
    })

    it('group_by_values_unique', 0, () => {
      const all: number = GROUP_BY_NONE | GROUP_BY_LAST_MODIFIED_DAILY | GROUP_BY_DATE_TAKEN_DAILY |
        GROUP_BY_FILE_TYPE | GROUP_BY_EXTENSION | GROUP_BY_FOLDER
      const sum: number = GROUP_BY_NONE + GROUP_BY_LAST_MODIFIED_DAILY + GROUP_BY_DATE_TAKEN_DAILY +
        GROUP_BY_FILE_TYPE + GROUP_BY_EXTENSION + GROUP_BY_FOLDER
      expect(all).assertEqual(sum)
    })

    // ---- Rounded corners ----

    it('rounded_corners_values_distinct', 0, () => {
      expect(ROUNDED_CORNERS_NONE !== ROUNDED_CORNERS_SMALL).assertEqual(true)
      expect(ROUNDED_CORNERS_SMALL !== ROUNDED_CORNERS_BIG).assertEqual(true)
      expect(ROUNDED_CORNERS_NONE !== ROUNDED_CORNERS_BIG).assertEqual(true)
    })

    // ---- Folder style ----

    it('folder_styles_distinct', 0, () => {
      expect(FOLDER_STYLE_SQUARE !== FOLDER_STYLE_ROUNDED_CORNERS).assertEqual(true)
    })

    // ---- Rotation ----

    it('rotation_values_sequential', 0, () => {
      expect(ROTATE_BY_SYSTEM_SETTING).assertEqual(0)
      expect(ROTATE_BY_DEVICE_ROTATION).assertEqual(1)
      expect(ROTATE_BY_ASPECT_RATIO).assertEqual(2)
    })

    // ---- Priority ----

    it('priority_values_sequential', 0, () => {
      expect(PRIORITY_SPEED).assertEqual(0)
      expect(PRIORITY_COMPROMISE).assertEqual(1)
      expect(PRIORITY_VALIDITY).assertEqual(2)
    })

    // ---- getDefaultFileFilter ----

    it('getDefaultFileFilter_includes_images_videos_gifs_raws_svgs', 0, () => {
      const filter: number = getDefaultFileFilter()
      expect((filter & TYPE_IMAGES) !== 0).assertEqual(true)
      expect((filter & TYPE_VIDEOS) !== 0).assertEqual(true)
      expect((filter & TYPE_GIFS) !== 0).assertEqual(true)
      expect((filter & TYPE_RAWS) !== 0).assertEqual(true)
      expect((filter & TYPE_SVGS) !== 0).assertEqual(true)
    })

    it('getDefaultFileFilter_excludes_portraits', 0, () => {
      const filter: number = getDefaultFileFilter()
      expect((filter & TYPE_PORTRAITS)).assertEqual(0)
    })
  })
}

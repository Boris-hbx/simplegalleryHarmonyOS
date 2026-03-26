import { describe, it, expect } from '@ohos/hypium'
import { Medium } from '../../../main/ets/common/models/Medium'
import {
  TYPE_IMAGES,
  TYPE_VIDEOS,
  TYPE_GIFS,
  TYPE_RAWS,
  TYPE_SVGS,
  TYPE_PORTRAITS,
  SORT_BY_NAME,
  SORT_BY_SIZE,
  SORT_BY_DATE_MODIFIED,
  SORT_BY_DATE_TAKEN,
  SORT_BY_PATH,
  GROUP_BY_FILE_TYPE,
  GROUP_BY_EXTENSION,
  GROUP_BY_FOLDER,
  GROUP_BY_NONE
} from '../../../main/ets/common/constants/Constants'

export default function MediumModelTest() {
  describe('MediumModelTest', () => {

    // ---- Constructor ----

    it('constructor_default_values', 0, () => {
      const m: Medium = new Medium()
      expect(m.id).assertEqual(0)
      expect(m.name).assertEqual('')
      expect(m.path).assertEqual('')
      expect(m.parentPath).assertEqual('')
      expect(m.modified).assertEqual(0)
      expect(m.taken).assertEqual(0)
      expect(m.size).assertEqual(0)
      expect(m.type).assertEqual(0)
      expect(m.videoDuration).assertEqual(0)
      expect(m.isFavorite).assertEqual(false)
      expect(m.deletedTS).assertEqual(0)
      expect(m.mediaStoreId).assertEqual(0)
    })

    it('constructor_assigns_all_fields', 0, () => {
      const m: Medium = new Medium(1, 'photo.jpg', '/a/photo.jpg', '/a', 100, 200, 1024, TYPE_IMAGES, 0, true, 0, 42)
      expect(m.id).assertEqual(1)
      expect(m.name).assertEqual('photo.jpg')
      expect(m.path).assertEqual('/a/photo.jpg')
      expect(m.parentPath).assertEqual('/a')
      expect(m.modified).assertEqual(100)
      expect(m.taken).assertEqual(200)
      expect(m.size).assertEqual(1024)
      expect(m.type).assertEqual(TYPE_IMAGES)
      expect(m.isFavorite).assertEqual(true)
      expect(m.mediaStoreId).assertEqual(42)
    })

    // ---- Type checks ----

    it('isImage_returns_true_for_TYPE_IMAGES', 0, () => {
      const m: Medium = new Medium(0, '', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m.isImage()).assertEqual(true)
      expect(m.isVideo()).assertEqual(false)
      expect(m.isGIF()).assertEqual(false)
    })

    it('isVideo_returns_true_for_TYPE_VIDEOS', 0, () => {
      const m: Medium = new Medium(0, '', '', '', 0, 0, 0, TYPE_VIDEOS)
      expect(m.isVideo()).assertEqual(true)
      expect(m.isImage()).assertEqual(false)
    })

    it('isGIF_returns_true_for_TYPE_GIFS', 0, () => {
      const m: Medium = new Medium(0, '', '', '', 0, 0, 0, TYPE_GIFS)
      expect(m.isGIF()).assertEqual(true)
      expect(m.isImage()).assertEqual(false)
    })

    it('isRaw_returns_true_for_TYPE_RAWS', 0, () => {
      const m: Medium = new Medium(0, '', '', '', 0, 0, 0, TYPE_RAWS)
      expect(m.isRaw()).assertEqual(true)
    })

    it('isSVG_returns_true_for_TYPE_SVGS', 0, () => {
      const m: Medium = new Medium(0, '', '', '', 0, 0, 0, TYPE_SVGS)
      expect(m.isSVG()).assertEqual(true)
    })

    it('isPortrait_returns_true_for_TYPE_PORTRAITS', 0, () => {
      const m: Medium = new Medium(0, '', '', '', 0, 0, 0, TYPE_PORTRAITS)
      expect(m.isPortrait()).assertEqual(true)
    })

    // ---- Name-based type checks ----

    it('isWebP_detects_webp_extension', 0, () => {
      const m: Medium = new Medium(0, 'image.WEBP', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m.isWebP()).assertEqual(true)
    })

    it('isWebP_returns_false_for_jpg', 0, () => {
      const m: Medium = new Medium(0, 'image.jpg', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m.isWebP()).assertEqual(false)
    })

    it('isApng_detects_apng_extension', 0, () => {
      const m: Medium = new Medium(0, 'anim.apng', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m.isApng()).assertEqual(true)
    })

    it('isHeic_detects_heic_and_heif', 0, () => {
      const m1: Medium = new Medium(0, 'photo.heic', '', '', 0, 0, 0, TYPE_IMAGES)
      const m2: Medium = new Medium(0, 'photo.HEIF', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m1.isHeic()).assertEqual(true)
      expect(m2.isHeic()).assertEqual(true)
    })

    it('isHidden_detects_dot_prefix', 0, () => {
      const m1: Medium = new Medium(0, '.hidden.jpg', '', '', 0, 0, 0, TYPE_IMAGES)
      const m2: Medium = new Medium(0, 'normal.jpg', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m1.isHidden()).assertEqual(true)
      expect(m2.isHidden()).assertEqual(false)
    })

    // ---- Recycle bin ----

    it('getIsInRecycleBin_true_when_deletedTS_nonzero', 0, () => {
      const m: Medium = new Medium(0, '', '', '', 0, 0, 0, 0, 0, false, 12345)
      expect(m.getIsInRecycleBin()).assertEqual(true)
    })

    it('getIsInRecycleBin_false_when_deletedTS_zero', 0, () => {
      const m: Medium = new Medium()
      expect(m.getIsInRecycleBin()).assertEqual(false)
    })

    // ---- Signature ----

    it('getSignature_uses_modified_when_greater_than_1', 0, () => {
      const m: Medium = new Medium(0, '', '/a/b.jpg', '', 500, 200, 1024, TYPE_IMAGES)
      expect(m.getSignature()).assertEqual('/a/b.jpg-500-1024')
    })

    it('getSignature_uses_taken_when_modified_le_1', 0, () => {
      const m: Medium = new Medium(0, '', '/a/b.jpg', '', 0, 200, 1024, TYPE_IMAGES)
      expect(m.getSignature()).assertEqual('/a/b.jpg-200-1024')
    })

    // ---- getBubbleText ----

    it('getBubbleText_returns_name_for_SORT_BY_NAME', 0, () => {
      const m: Medium = new Medium(0, 'photo.jpg', '/a/photo.jpg', '/a', 0, 0, 0, TYPE_IMAGES)
      expect(m.getBubbleText(SORT_BY_NAME)).assertEqual('photo.jpg')
    })

    it('getBubbleText_returns_path_for_SORT_BY_PATH', 0, () => {
      const m: Medium = new Medium(0, 'photo.jpg', '/a/photo.jpg', '/a', 0, 0, 0, TYPE_IMAGES)
      expect(m.getBubbleText(SORT_BY_PATH)).assertEqual('/a/photo.jpg')
    })

    // ---- getGroupingKey ----

    it('getGroupingKey_returns_type_string_for_GROUP_BY_FILE_TYPE', 0, () => {
      const m: Medium = new Medium(0, 'a.jpg', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m.getGroupingKey(GROUP_BY_FILE_TYPE)).assertEqual(TYPE_IMAGES.toString())
    })

    it('getGroupingKey_returns_extension_for_GROUP_BY_EXTENSION', 0, () => {
      const m: Medium = new Medium(0, 'photo.JPG', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m.getGroupingKey(GROUP_BY_EXTENSION)).assertEqual('jpg')
    })

    it('getGroupingKey_returns_parentPath_for_GROUP_BY_FOLDER', 0, () => {
      const m: Medium = new Medium(0, 'a.jpg', '/pics/a.jpg', '/pics', 0, 0, 0, TYPE_IMAGES)
      expect(m.getGroupingKey(GROUP_BY_FOLDER)).assertEqual('/pics')
    })

    it('getGroupingKey_returns_empty_for_GROUP_BY_NONE', 0, () => {
      const m: Medium = new Medium(0, 'a.jpg', '', '', 0, 0, 0, TYPE_IMAGES)
      expect(m.getGroupingKey(GROUP_BY_NONE)).assertEqual('')
    })
  })
}

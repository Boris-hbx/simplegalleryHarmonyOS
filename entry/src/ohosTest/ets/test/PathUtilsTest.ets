import { describe, it, expect } from '@ohos/hypium'
import {
  shouldFolderBeVisible,
  isThisOrParentIncluded,
  isThisOrParentExcluded,
  isThisOrParentFolderHidden,
  isDownloadsFolder
} from '../../../main/ets/utils/PathUtils'

export default function PathUtilsTest() {
  describe('PathUtilsTest', () => {

    // ---- isThisOrParentIncluded ----

    it('isThisOrParentIncluded_exact_match', 0, () => {
      expect(isThisOrParentIncluded('/photos', ['/photos'])).assertEqual(true)
    })

    it('isThisOrParentIncluded_child_path', 0, () => {
      expect(isThisOrParentIncluded('/photos/2024', ['/photos'])).assertEqual(true)
    })

    it('isThisOrParentIncluded_no_match', 0, () => {
      expect(isThisOrParentIncluded('/videos', ['/photos'])).assertEqual(false)
    })

    it('isThisOrParentIncluded_empty_list', 0, () => {
      expect(isThisOrParentIncluded('/photos', [])).assertEqual(false)
    })

    // ---- isThisOrParentExcluded ----

    it('isThisOrParentExcluded_exact_match', 0, () => {
      expect(isThisOrParentExcluded('/private', ['/private'])).assertEqual(true)
    })

    it('isThisOrParentExcluded_child_path', 0, () => {
      expect(isThisOrParentExcluded('/private/docs', ['/private'])).assertEqual(true)
    })

    it('isThisOrParentExcluded_no_match', 0, () => {
      expect(isThisOrParentExcluded('/public', ['/private'])).assertEqual(false)
    })

    // ---- isThisOrParentFolderHidden ----

    it('isHidden_dot_folder_in_path', 0, () => {
      expect(isThisOrParentFolderHidden('/photos/.hidden/img.jpg')).assertEqual(true)
    })

    it('isHidden_dot_at_leaf', 0, () => {
      expect(isThisOrParentFolderHidden('/photos/.secret')).assertEqual(true)
    })

    it('isHidden_no_dot_folder', 0, () => {
      expect(isThisOrParentFolderHidden('/photos/vacation')).assertEqual(false)
    })

    it('isHidden_root_path', 0, () => {
      expect(isThisOrParentFolderHidden('/')).assertEqual(false)
    })

    it('isHidden_empty_string', 0, () => {
      expect(isThisOrParentFolderHidden('')).assertEqual(false)
    })

    // ---- shouldFolderBeVisible ----

    it('shouldFolderBeVisible_included_overrides_excluded', 0, () => {
      expect(shouldFolderBeVisible('/special', ['/special'], ['/special'], false)).assertEqual(true)
    })

    it('shouldFolderBeVisible_excluded_folder', 0, () => {
      expect(shouldFolderBeVisible('/excluded', ['/excluded'], [], true)).assertEqual(false)
    })

    it('shouldFolderBeVisible_hidden_folder_showHidden_false', 0, () => {
      expect(shouldFolderBeVisible('/photos/.hidden', [], [], false)).assertEqual(false)
    })

    it('shouldFolderBeVisible_hidden_folder_showHidden_true', 0, () => {
      expect(shouldFolderBeVisible('/photos/.hidden', [], [], true)).assertEqual(true)
    })

    it('shouldFolderBeVisible_normal_folder', 0, () => {
      expect(shouldFolderBeVisible('/photos/vacation', [], [], false)).assertEqual(true)
    })

    // ---- isDownloadsFolder ----

    it('isDownloadsFolder_download', 0, () => {
      expect(isDownloadsFolder('/storage/Download')).assertEqual(true)
    })

    it('isDownloadsFolder_downloads', 0, () => {
      expect(isDownloadsFolder('/storage/Downloads')).assertEqual(true)
    })

    it('isDownloadsFolder_case_insensitive', 0, () => {
      expect(isDownloadsFolder('/storage/DOWNLOAD')).assertEqual(true)
    })

    it('isDownloadsFolder_not_downloads', 0, () => {
      expect(isDownloadsFolder('/storage/Photos')).assertEqual(false)
    })
  })
}

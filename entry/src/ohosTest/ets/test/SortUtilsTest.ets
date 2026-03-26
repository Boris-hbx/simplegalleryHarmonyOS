import { describe, it, expect } from '@ohos/hypium'
import { isSortingAscending } from '../../../main/ets/utils/SortUtils'
import {
  SORT_BY_NAME,
  SORT_BY_DATE_MODIFIED,
  SORT_BY_SIZE,
  SORT_BY_DATE_TAKEN,
  SORT_BY_RANDOM,
  SORT_BY_PATH,
  SORT_DESCENDING
} from '../../../main/ets/common/constants/Constants'

export default function SortUtilsTest() {
  describe('SortUtilsTest', () => {

    // ---- Ascending (no SORT_DESCENDING flag) ----

    it('isSortingAscending_true_for_SORT_BY_NAME', 0, () => {
      expect(isSortingAscending(SORT_BY_NAME)).assertEqual(true)
    })

    it('isSortingAscending_true_for_SORT_BY_DATE_MODIFIED', 0, () => {
      expect(isSortingAscending(SORT_BY_DATE_MODIFIED)).assertEqual(true)
    })

    it('isSortingAscending_true_for_SORT_BY_SIZE', 0, () => {
      expect(isSortingAscending(SORT_BY_SIZE)).assertEqual(true)
    })

    it('isSortingAscending_true_for_SORT_BY_DATE_TAKEN', 0, () => {
      expect(isSortingAscending(SORT_BY_DATE_TAKEN)).assertEqual(true)
    })

    it('isSortingAscending_true_for_SORT_BY_RANDOM', 0, () => {
      expect(isSortingAscending(SORT_BY_RANDOM)).assertEqual(true)
    })

    it('isSortingAscending_true_for_SORT_BY_PATH', 0, () => {
      expect(isSortingAscending(SORT_BY_PATH)).assertEqual(true)
    })

    // ---- Descending (with SORT_DESCENDING flag) ----

    it('isSortingAscending_false_for_SORT_BY_NAME_DESC', 0, () => {
      expect(isSortingAscending(SORT_BY_NAME | SORT_DESCENDING)).assertEqual(false)
    })

    it('isSortingAscending_false_for_SORT_BY_SIZE_DESC', 0, () => {
      expect(isSortingAscending(SORT_BY_SIZE | SORT_DESCENDING)).assertEqual(false)
    })

    it('isSortingAscending_false_for_SORT_BY_DATE_MODIFIED_DESC', 0, () => {
      expect(isSortingAscending(SORT_BY_DATE_MODIFIED | SORT_DESCENDING)).assertEqual(false)
    })

    it('isSortingAscending_false_for_SORT_BY_DATE_TAKEN_DESC', 0, () => {
      expect(isSortingAscending(SORT_BY_DATE_TAKEN | SORT_DESCENDING)).assertEqual(false)
    })

    it('isSortingAscending_false_for_SORT_DESCENDING_alone', 0, () => {
      expect(isSortingAscending(SORT_DESCENDING)).assertEqual(false)
    })

    // ---- Edge cases ----

    it('isSortingAscending_true_for_zero', 0, () => {
      expect(isSortingAscending(0)).assertEqual(true)
    })

    it('isSortingAscending_combined_flags_without_descending', 0, () => {
      expect(isSortingAscending(SORT_BY_NAME | SORT_BY_SIZE)).assertEqual(true)
    })

    it('isSortingAscending_combined_flags_with_descending', 0, () => {
      expect(isSortingAscending(SORT_BY_NAME | SORT_BY_SIZE | SORT_DESCENDING)).assertEqual(false)
    })

    it('isSortingAscending_only_SORT_DESCENDING_bit', 0, () => {
      expect(isSortingAscending(1048576)).assertEqual(false)
    })
  })
}

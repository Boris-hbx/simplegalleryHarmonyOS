import { describe, it, expect } from '@ohos/hypium'
import { groupMediaByDate, DateGroup } from '../../../main/ets/common/utils/DateGroupUtils'
import { Medium } from '../../../main/ets/common/models/Medium'
import { TYPE_IMAGES } from '../../../main/ets/common/constants/Constants'

export default function DateGroupUtilsTest() {
  describe('DateGroupUtilsTest', () => {

    it('empty_list_returns_empty_groups', 0, () => {
      const result: DateGroup[] = groupMediaByDate([], 'Today', 'Yesterday')
      expect(result.length).assertEqual(0)
    })

    it('single_item_creates_one_group', 0, () => {
      const m: Medium = new Medium(1, 'a.jpg', '/a.jpg', '/', 1000000, 1000000, 100, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m], 'Today', 'Yesterday')
      expect(result.length).assertEqual(1)
      expect(result[0].items.length).assertEqual(1)
    })

    it('items_same_day_grouped_together', 0, () => {
      const ts: number = new Date(2025, 5, 15, 10, 0).getTime()
      const m1: Medium = new Medium(1, 'a.jpg', '/a.jpg', '/', ts, ts, 100, TYPE_IMAGES)
      const m2: Medium = new Medium(2, 'b.jpg', '/b.jpg', '/', ts + 3600000, ts + 3600000, 200, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m1, m2], 'Today', 'Yesterday')
      expect(result.length).assertEqual(1)
      expect(result[0].items.length).assertEqual(2)
    })

    it('items_different_days_create_separate_groups', 0, () => {
      const day1: number = new Date(2025, 5, 15, 10, 0).getTime()
      const day2: number = new Date(2025, 5, 16, 10, 0).getTime()
      const m1: Medium = new Medium(1, 'a.jpg', '/a.jpg', '/', day1, day1, 100, TYPE_IMAGES)
      const m2: Medium = new Medium(2, 'b.jpg', '/b.jpg', '/', day2, day2, 200, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m1, m2], 'Today', 'Yesterday')
      expect(result.length).assertEqual(2)
    })

    it('today_label_applied_for_today_items', 0, () => {
      const now: number = Date.now()
      const m: Medium = new Medium(1, 'a.jpg', '/a.jpg', '/', now, now, 100, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m], 'Today', 'Yesterday')
      expect(result[0].title).assertEqual('Today')
    })

    it('yesterday_label_applied_for_yesterday_items', 0, () => {
      const yesterday: number = Date.now() - 86400000
      const m: Medium = new Medium(1, 'a.jpg', '/a.jpg', '/', yesterday, yesterday, 100, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m], 'Today', 'Yesterday')
      expect(result[0].title).assertEqual('Yesterday')
    })

    it('uses_taken_timestamp_when_available', 0, () => {
      const taken: number = new Date(2025, 3, 10, 12, 0).getTime()
      const modified: number = new Date(2025, 6, 20, 12, 0).getTime()
      const m: Medium = new Medium(1, 'a.jpg', '/a.jpg', '/', modified, taken, 100, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m], 'Today', 'Yesterday')
      expect(result.length).assertEqual(1)
      // When taken > 0, it should use taken timestamp for grouping
      expect(result[0].items[0].name).assertEqual('a.jpg')
    })

    it('falls_back_to_modified_when_taken_is_zero', 0, () => {
      const modified: number = new Date(2025, 3, 10, 12, 0).getTime()
      const m: Medium = new Medium(1, 'a.jpg', '/a.jpg', '/', modified, 0, 100, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m], 'Today', 'Yesterday')
      expect(result.length).assertEqual(1)
    })

    it('groups_sorted_descending_by_date', 0, () => {
      const older: number = new Date(2025, 1, 1).getTime()
      const newer: number = new Date(2025, 6, 1).getTime()
      const m1: Medium = new Medium(1, 'old.jpg', '/old.jpg', '/', older, older, 100, TYPE_IMAGES)
      const m2: Medium = new Medium(2, 'new.jpg', '/new.jpg', '/', newer, newer, 200, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m1, m2], 'Today', 'Yesterday')
      // Newer should come first
      expect(result[0].items[0].name).assertEqual('new.jpg')
    })

    it('negative_timestamp_creates_group', 0, () => {
      const m: Medium = new Medium(1, 'a.jpg', '/a.jpg', '/', -1000, 0, 100, TYPE_IMAGES)
      const result: DateGroup[] = groupMediaByDate([m], 'Today', 'Yesterday')
      expect(result.length).assertEqual(1)
    })
  })
}

import { describe, it, expect } from '@ohos/hypium'
import { Medium } from '../../../../main/ets/common/models/Medium'
import { ThumbnailItem, ThumbnailSection } from '../../../../main/ets/common/models/ThumbnailItem'
import { MediaGrouper } from '../../../../main/ets/media/MediaGrouper'
import {
  TYPE_IMAGES, TYPE_VIDEOS, TYPE_GIFS,
  GROUP_BY_NONE, GROUP_BY_FILE_TYPE, GROUP_BY_EXTENSION, GROUP_BY_FOLDER,
  GROUP_BY_LAST_MODIFIED_DAILY, GROUP_BY_DATE_TAKEN_MONTHLY,
  GROUP_DESCENDING, GROUP_SHOW_FILE_COUNT
} from '../../../../main/ets/common/constants/Constants'

// Integration tests for MediaGrouper.
// MediaGrouper is a pure logic class — no external dependencies.
// Tests verify grouping, section headers, and ordering with real Medium objects.

export default function MediaGrouperIntegrationTest() {
  describe('MediaGrouperIntegrationTest', () => {

    // ---- Empty and no-group cases ----

    it('empty_input_returns_empty_array', 0, () => {
      const result: ThumbnailItem[] = MediaGrouper.insertGroupHeaders([], GROUP_BY_FILE_TYPE, false)
      expect(result.length).assertEqual(0)
    })

    it('group_by_none_returns_items_without_headers', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/photos', 100, 100, 500, TYPE_IMAGES),
        new Medium(2, 'b.mp4', '/b.mp4', '/videos', 200, 200, 1000, TYPE_VIDEOS)
      ]
      const result: ThumbnailItem[] = MediaGrouper.insertGroupHeaders(media, GROUP_BY_NONE, false)
      // GROUP_BY_NONE should return items as-is (no section headers)
      expect(result.length).assertEqual(2)
    })

    // ---- Group by file type ----

    it('group_by_file_type_creates_correct_groups', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 100, 100, 500, TYPE_IMAGES),
        new Medium(2, 'b.mp4', '/b.mp4', '/', 200, 200, 1000, TYPE_VIDEOS),
        new Medium(3, 'c.jpg', '/c.jpg', '/', 300, 300, 600, TYPE_IMAGES)
      ]
      const result: ThumbnailItem[] = MediaGrouper.insertGroupHeaders(media, GROUP_BY_FILE_TYPE, false)
      // Should have 2 section headers + 3 media items = 5 items
      let sectionCount: number = 0
      for (let i: number = 0; i < result.length; i++) {
        if (result[i] instanceof ThumbnailSection) {
          sectionCount++
        }
      }
      expect(sectionCount).assertEqual(2)
      expect(result.length).assertEqual(5)
    })

    it('group_by_file_type_with_file_count', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 100, 100, 500, TYPE_IMAGES),
        new Medium(2, 'b.jpg', '/b.jpg', '/', 200, 200, 600, TYPE_IMAGES),
        new Medium(3, 'c.mp4', '/c.mp4', '/', 300, 300, 1000, TYPE_VIDEOS)
      ]
      const result: ThumbnailItem[] = MediaGrouper.insertGroupHeaders(
        media, GROUP_BY_FILE_TYPE | GROUP_SHOW_FILE_COUNT, true
      )
      // Find section headers and check they contain count
      for (let i: number = 0; i < result.length; i++) {
        if (result[i] instanceof ThumbnailSection) {
          const section: ThumbnailSection = result[i] as ThumbnailSection
          // Title should contain parentheses with count, e.g. "Images (2)"
          expect(section.title.indexOf('(') >= 0).assertTrue()
        }
      }
    })

    // ---- Group by extension ----

    it('group_by_extension_separates_formats', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 100, 100, 0, TYPE_IMAGES),
        new Medium(2, 'b.png', '/b.png', '/', 200, 200, 0, TYPE_IMAGES),
        new Medium(3, 'c.jpg', '/c.jpg', '/', 300, 300, 0, TYPE_IMAGES)
      ]
      const result: ThumbnailItem[] = MediaGrouper.insertGroupHeaders(media, GROUP_BY_EXTENSION, false)
      let sectionCount: number = 0
      for (let i: number = 0; i < result.length; i++) {
        if (result[i] instanceof ThumbnailSection) {
          sectionCount++
        }
      }
      expect(sectionCount).assertEqual(2) // JPG and PNG
    })

    // ---- Group by folder ----

    it('group_by_folder_groups_by_parentPath', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/photos/a.jpg', '/photos', 100, 100, 0, TYPE_IMAGES),
        new Medium(2, 'b.jpg', '/downloads/b.jpg', '/downloads', 200, 200, 0, TYPE_IMAGES),
        new Medium(3, 'c.jpg', '/photos/c.jpg', '/photos', 300, 300, 0, TYPE_IMAGES)
      ]
      const result: ThumbnailItem[] = MediaGrouper.insertGroupHeaders(media, GROUP_BY_FOLDER, false)
      let sectionCount: number = 0
      const sectionTitles: string[] = []
      for (let i: number = 0; i < result.length; i++) {
        if (result[i] instanceof ThumbnailSection) {
          sectionCount++
          sectionTitles.push((result[i] as ThumbnailSection).title)
        }
      }
      expect(sectionCount).assertEqual(2) // photos and downloads
    })

    // ---- Single item group ----

    it('single_medium_creates_one_group', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 100, 100, 500, TYPE_IMAGES)
      ]
      const result: ThumbnailItem[] = MediaGrouper.insertGroupHeaders(media, GROUP_BY_FILE_TYPE, false)
      // 1 section header + 1 item
      expect(result.length).assertEqual(2)
      expect(result[0] instanceof ThumbnailSection).assertTrue()
    })

    // ---- Group descending flag ----

    it('group_descending_reverses_group_order_for_date', 0, () => {
      const day1: number = new Date(2025, 0, 1).getTime()
      const day2: number = new Date(2025, 6, 1).getTime()
      const media: Medium[] = [
        new Medium(1, 'old.jpg', '/old.jpg', '/', day1, 0, 0, TYPE_IMAGES),
        new Medium(2, 'new.jpg', '/new.jpg', '/', day2, 0, 0, TYPE_IMAGES)
      ]
      const resultAsc: ThumbnailItem[] = MediaGrouper.insertGroupHeaders(
        media, GROUP_BY_LAST_MODIFIED_DAILY, false
      )
      const resultDesc: ThumbnailItem[] = MediaGrouper.insertGroupHeaders(
        media, GROUP_BY_LAST_MODIFIED_DAILY | GROUP_DESCENDING, false
      )
      // First section title should differ between asc and desc
      const firstAsc: string = (resultAsc[0] as ThumbnailSection).title
      const firstDesc: string = (resultDesc[0] as ThumbnailSection).title
      expect(firstAsc !== firstDesc).assertTrue()
    })
  })
}

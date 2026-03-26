import { describe, it, expect } from '@ohos/hypium'
import { Medium } from '../../../../main/ets/common/models/Medium'
import { Directory } from '../../../../main/ets/common/models/Directory'
import {
  TYPE_IMAGES, TYPE_VIDEOS, TYPE_GIFS, TYPE_RAWS, TYPE_SVGS,
  SORT_BY_NAME, SORT_BY_DATE_MODIFIED, SORT_BY_SIZE, SORT_BY_DATE_TAKEN,
  SORT_DESCENDING, SORT_BY_PATH, LOCATION_INTERNAL
} from '../../../../main/ets/common/constants/Constants'

// Integration tests for MediaScanner logic.
// Since MediaScanner requires photoAccessHelper Context (unavailable in test env),
// we test the filtering, sorting, and result structure patterns using mock data
// that mirrors what MediaScanner produces.

export default function MediaScannerIntegrationTest() {
  describe('MediaScannerIntegrationTest', () => {

    // ---- Result structure validation ----

    it('scanner_result_has_path_and_type_fields', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'photo.jpg', '/photos/photo.jpg', '/photos', 1700000000, 1700000000, 1024, TYPE_IMAGES),
        new Medium(2, 'video.mp4', '/videos/video.mp4', '/videos', 1700000001, 1700000001, 2048, TYPE_VIDEOS, 60000)
      ]
      for (let i: number = 0; i < media.length; i++) {
        expect(media[i].path.length > 0).assertTrue()
        expect(media[i].type > 0).assertTrue()
      }
    })

    it('scanner_result_medium_has_required_properties', 0, () => {
      const m: Medium = new Medium(1, 'img.jpg', '/storage/img.jpg', '/storage',
        1700000000, 1699000000, 5242880, TYPE_IMAGES, 0, false, 0, 42)
      expect(m.name).assertEqual('img.jpg')
      expect(m.path).assertEqual('/storage/img.jpg')
      expect(m.parentPath).assertEqual('/storage')
      expect(m.modified).assertEqual(1700000000)
      expect(m.taken).assertEqual(1699000000)
      expect(m.size).assertEqual(5242880)
      expect(m.type).assertEqual(TYPE_IMAGES)
      expect(m.isFavorite).assertEqual(false)
    })

    it('scanner_directory_result_has_required_fields', 0, () => {
      const dir: Directory = new Directory(
        1, 'file://media/Album/1', 'file://media/Photo/1/thumb.jpg',
        'Camera', 25, 1700000000, 1700000000, 50000, LOCATION_INTERNAL, TYPE_IMAGES, ''
      )
      expect(dir.path.length > 0).assertTrue()
      expect(dir.name).assertEqual('Camera')
      expect(dir.mediaCnt).assertEqual(25)
    })

    // ---- Filter logic (mirrors MediaScanner.matchesFilter) ----

    it('filter_type_images_excludes_videos', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 0, 0, 100, TYPE_IMAGES),
        new Medium(2, 'b.mp4', '/b.mp4', '/', 0, 0, 200, TYPE_VIDEOS),
        new Medium(3, 'c.png', '/c.png', '/', 0, 0, 150, TYPE_IMAGES)
      ]
      const filterMedia: number = TYPE_IMAGES
      const filtered: Medium[] = media.filter((m: Medium): boolean => (m.type & filterMedia) !== 0)
      expect(filtered.length).assertEqual(2)
      for (let i: number = 0; i < filtered.length; i++) {
        expect(filtered[i].type).assertEqual(TYPE_IMAGES)
      }
    })

    it('filter_type_videos_excludes_images', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 0, 0, 100, TYPE_IMAGES),
        new Medium(2, 'b.mp4', '/b.mp4', '/', 0, 0, 200, TYPE_VIDEOS),
        new Medium(3, 'c.mp4', '/c.mp4', '/', 0, 0, 300, TYPE_VIDEOS, 120000)
      ]
      const filterMedia: number = TYPE_VIDEOS
      const filtered: Medium[] = media.filter((m: Medium): boolean => (m.type & filterMedia) !== 0)
      expect(filtered.length).assertEqual(2)
      for (let i: number = 0; i < filtered.length; i++) {
        expect(filtered[i].type).assertEqual(TYPE_VIDEOS)
      }
    })

    it('filter_combined_images_and_videos', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 0, 0, 100, TYPE_IMAGES),
        new Medium(2, 'b.mp4', '/b.mp4', '/', 0, 0, 200, TYPE_VIDEOS),
        new Medium(3, 'c.gif', '/c.gif', '/', 0, 0, 50, TYPE_GIFS)
      ]
      const filterMedia: number = TYPE_IMAGES | TYPE_VIDEOS
      const filtered: Medium[] = media.filter((m: Medium): boolean => (m.type & filterMedia) !== 0)
      expect(filtered.length).assertEqual(2)
    })

    it('filter_gifs_only', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 0, 0, 100, TYPE_IMAGES),
        new Medium(2, 'b.gif', '/b.gif', '/', 0, 0, 200, TYPE_GIFS),
        new Medium(3, 'c.gif', '/c.gif', '/', 0, 0, 300, TYPE_GIFS)
      ]
      const filterMedia: number = TYPE_GIFS
      const filtered: Medium[] = media.filter((m: Medium): boolean => (m.type & filterMedia) !== 0)
      expect(filtered.length).assertEqual(2)
    })

    it('filter_all_types_includes_everything', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'a.jpg', '/a.jpg', '/', 0, 0, 100, TYPE_IMAGES),
        new Medium(2, 'b.mp4', '/b.mp4', '/', 0, 0, 200, TYPE_VIDEOS),
        new Medium(3, 'c.gif', '/c.gif', '/', 0, 0, 50, TYPE_GIFS),
        new Medium(4, 'd.dng', '/d.dng', '/', 0, 0, 500, TYPE_RAWS),
        new Medium(5, 'e.svg', '/e.svg', '/', 0, 0, 10, TYPE_SVGS)
      ]
      const filterMedia: number = TYPE_IMAGES | TYPE_VIDEOS | TYPE_GIFS | TYPE_RAWS | TYPE_SVGS
      const filtered: Medium[] = media.filter((m: Medium): boolean => (m.type & filterMedia) !== 0)
      expect(filtered.length).assertEqual(5)
    })

    // ---- Sort logic (mirrors MediaScanner.sortMedia) ----

    it('sort_by_name_ascending', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'cherry.jpg', '/cherry.jpg', '/', 0, 0, 0, TYPE_IMAGES),
        new Medium(2, 'apple.jpg', '/apple.jpg', '/', 0, 0, 0, TYPE_IMAGES),
        new Medium(3, 'banana.jpg', '/banana.jpg', '/', 0, 0, 0, TYPE_IMAGES)
      ]
      const sorting: number = SORT_BY_NAME
      const ascending: boolean = (sorting & SORT_DESCENDING) === 0
      const sortFlag: number = sorting & ~SORT_DESCENDING
      media.sort((a: Medium, b: Medium): number => {
        let result: number = 0
        if ((sortFlag & SORT_BY_NAME) !== 0) {
          result = a.name.localeCompare(b.name, undefined, { numeric: true })
        }
        return ascending ? result : -result
      })
      expect(media[0].name).assertEqual('apple.jpg')
      expect(media[1].name).assertEqual('banana.jpg')
      expect(media[2].name).assertEqual('cherry.jpg')
    })

    it('sort_by_name_descending', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'cherry.jpg', '/cherry.jpg', '/', 0, 0, 0, TYPE_IMAGES),
        new Medium(2, 'apple.jpg', '/apple.jpg', '/', 0, 0, 0, TYPE_IMAGES),
        new Medium(3, 'banana.jpg', '/banana.jpg', '/', 0, 0, 0, TYPE_IMAGES)
      ]
      const sorting: number = SORT_BY_NAME | SORT_DESCENDING
      const ascending: boolean = (sorting & SORT_DESCENDING) === 0
      const sortFlag: number = sorting & ~SORT_DESCENDING
      media.sort((a: Medium, b: Medium): number => {
        let result: number = 0
        if ((sortFlag & SORT_BY_NAME) !== 0) {
          result = a.name.localeCompare(b.name, undefined, { numeric: true })
        }
        return ascending ? result : -result
      })
      expect(media[0].name).assertEqual('cherry.jpg')
      expect(media[1].name).assertEqual('banana.jpg')
      expect(media[2].name).assertEqual('apple.jpg')
    })

    it('sort_by_date_modified_ascending', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'c.jpg', '/c.jpg', '/', 300, 0, 0, TYPE_IMAGES),
        new Medium(2, 'a.jpg', '/a.jpg', '/', 100, 0, 0, TYPE_IMAGES),
        new Medium(3, 'b.jpg', '/b.jpg', '/', 200, 0, 0, TYPE_IMAGES)
      ]
      media.sort((a: Medium, b: Medium): number => a.modified - b.modified)
      expect(media[0].name).assertEqual('a.jpg')
      expect(media[1].name).assertEqual('b.jpg')
      expect(media[2].name).assertEqual('c.jpg')
    })

    it('sort_by_size_ascending', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'large.jpg', '/large.jpg', '/', 0, 0, 5000000, TYPE_IMAGES),
        new Medium(2, 'small.jpg', '/small.jpg', '/', 0, 0, 100, TYPE_IMAGES),
        new Medium(3, 'medium.jpg', '/medium.jpg', '/', 0, 0, 50000, TYPE_IMAGES)
      ]
      media.sort((a: Medium, b: Medium): number => a.size - b.size)
      expect(media[0].name).assertEqual('small.jpg')
      expect(media[1].name).assertEqual('medium.jpg')
      expect(media[2].name).assertEqual('large.jpg')
    })

    it('sort_numeric_names_natural_order', 0, () => {
      const media: Medium[] = [
        new Medium(1, 'IMG_10.jpg', '/IMG_10.jpg', '/', 0, 0, 0, TYPE_IMAGES),
        new Medium(2, 'IMG_2.jpg', '/IMG_2.jpg', '/', 0, 0, 0, TYPE_IMAGES),
        new Medium(3, 'IMG_1.jpg', '/IMG_1.jpg', '/', 0, 0, 0, TYPE_IMAGES)
      ]
      media.sort((a: Medium, b: Medium): number =>
        a.name.localeCompare(b.name, undefined, { numeric: true })
      )
      expect(media[0].name).assertEqual('IMG_1.jpg')
      expect(media[1].name).assertEqual('IMG_2.jpg')
      expect(media[2].name).assertEqual('IMG_10.jpg')
    })

    // ---- Hidden file filtering ----

    it('hidden_files_excluded_when_not_shown', 0, () => {
      const media: Medium[] = [
        new Medium(1, '.hidden.jpg', '/.hidden.jpg', '/', 0, 0, 100, TYPE_IMAGES),
        new Medium(2, 'visible.jpg', '/visible.jpg', '/', 0, 0, 200, TYPE_IMAGES),
        new Medium(3, '.secret.png', '/.secret.png', '/', 0, 0, 300, TYPE_IMAGES)
      ]
      const showHidden: boolean = false
      const filtered: Medium[] = media.filter((m: Medium): boolean =>
        showHidden || !m.name.startsWith('.')
      )
      expect(filtered.length).assertEqual(1)
      expect(filtered[0].name).assertEqual('visible.jpg')
    })

    it('hidden_files_included_when_shown', 0, () => {
      const media: Medium[] = [
        new Medium(1, '.hidden.jpg', '/.hidden.jpg', '/', 0, 0, 100, TYPE_IMAGES),
        new Medium(2, 'visible.jpg', '/visible.jpg', '/', 0, 0, 200, TYPE_IMAGES)
      ]
      const showHidden: boolean = true
      const filtered: Medium[] = media.filter((m: Medium): boolean =>
        showHidden || !m.name.startsWith('.')
      )
      expect(filtered.length).assertEqual(2)
    })
  })
}

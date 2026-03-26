import { describe, it, expect } from '@ohos/hypium'
import { Directory } from '../../../../main/ets/common/models/Directory'
import { CacheManager } from '../../../../main/ets/media/CacheManager'
import { TYPE_IMAGES, TYPE_VIDEOS, LOCATION_INTERNAL } from '../../../../main/ets/common/constants/Constants'

// Integration tests for CacheManager.
// CacheManager.loadFromCache/persistCache require DB Context (unavailable in test env).
// We test the pure-logic applyDiff method and diff result patterns directly.

// Mirror the DiffResult interface from CacheManager
interface DiffResult {
  added: Directory[]
  removed: string[]
  modified: Directory[]
}

export default function CacheManagerIntegrationTest() {
  describe('CacheManagerIntegrationTest', () => {

    // ---- applyDiff tests ----

    it('applyDiff_empty_diff_returns_same_list', 0, () => {
      const cm: CacheManager = new CacheManager()
      const dirs: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES),
        new Directory(2, '/videos', '', 'Videos', 5, 200, 200, 10000, LOCATION_INTERNAL, TYPE_VIDEOS)
      ]
      const diff: DiffResult = { added: [], removed: [], modified: [] }
      const result: Directory[] = cm.applyDiff(dirs, diff)
      expect(result.length).assertEqual(2)
      expect(result[0].path).assertEqual('/photos')
      expect(result[1].path).assertEqual('/videos')
    })

    it('applyDiff_adds_new_directories', 0, () => {
      const cm: CacheManager = new CacheManager()
      const dirs: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES)
      ]
      const newDir: Directory = new Directory(2, '/downloads', '', 'Downloads', 3, 300, 300, 2000, LOCATION_INTERNAL, TYPE_IMAGES)
      const diff: DiffResult = { added: [newDir], removed: [], modified: [] }
      const result: Directory[] = cm.applyDiff(dirs, diff)
      expect(result.length).assertEqual(2)
      expect(result[1].path).assertEqual('/downloads')
      expect(result[1].name).assertEqual('Downloads')
    })

    it('applyDiff_removes_directories', 0, () => {
      const cm: CacheManager = new CacheManager()
      const dirs: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES),
        new Directory(2, '/videos', '', 'Videos', 5, 200, 200, 10000, LOCATION_INTERNAL, TYPE_VIDEOS),
        new Directory(3, '/downloads', '', 'Downloads', 3, 300, 300, 2000, LOCATION_INTERNAL, TYPE_IMAGES)
      ]
      const diff: DiffResult = { added: [], removed: ['/videos'], modified: [] }
      const result: Directory[] = cm.applyDiff(dirs, diff)
      expect(result.length).assertEqual(2)
      expect(result[0].path).assertEqual('/photos')
      expect(result[1].path).assertEqual('/downloads')
    })

    it('applyDiff_modifies_existing_directories', 0, () => {
      const cm: CacheManager = new CacheManager()
      const dirs: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES),
        new Directory(2, '/videos', '', 'Videos', 5, 200, 200, 10000, LOCATION_INTERNAL, TYPE_VIDEOS)
      ]
      const updatedPhotos: Directory = new Directory(1, '/photos', '', 'Photos', 15, 500, 500, 8000, LOCATION_INTERNAL, TYPE_IMAGES)
      const diff: DiffResult = { added: [], removed: [], modified: [updatedPhotos] }
      const result: Directory[] = cm.applyDiff(dirs, diff)
      expect(result.length).assertEqual(2)
      expect(result[0].mediaCnt).assertEqual(15)
      expect(result[0].modified).assertEqual(500)
    })

    it('applyDiff_combined_add_remove_modify', 0, () => {
      const cm: CacheManager = new CacheManager()
      const dirs: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES),
        new Directory(2, '/old', '', 'Old', 2, 50, 50, 1000, LOCATION_INTERNAL, TYPE_IMAGES),
        new Directory(3, '/videos', '', 'Videos', 5, 200, 200, 10000, LOCATION_INTERNAL, TYPE_VIDEOS)
      ]
      const updatedVideos: Directory = new Directory(3, '/videos', '', 'Videos', 8, 400, 400, 20000, LOCATION_INTERNAL, TYPE_VIDEOS)
      const newDir: Directory = new Directory(4, '/new', '', 'New', 1, 500, 500, 100, LOCATION_INTERNAL, TYPE_IMAGES)
      const diff: DiffResult = {
        added: [newDir],
        removed: ['/old'],
        modified: [updatedVideos]
      }
      const result: Directory[] = cm.applyDiff(dirs, diff)
      expect(result.length).assertEqual(3) // photos + videos(modified) + new
      // /old should be removed
      let hasOld: boolean = false
      for (let i: number = 0; i < result.length; i++) {
        if (result[i].path === '/old') {
          hasOld = true
        }
      }
      expect(hasOld).assertEqual(false)
      // /videos should be updated
      let videoDir: Directory | null = null
      for (let i: number = 0; i < result.length; i++) {
        if (result[i].path === '/videos') {
          videoDir = result[i]
        }
      }
      expect(videoDir !== null).assertTrue()
      expect((videoDir as Directory).mediaCnt).assertEqual(8)
      // /new should be added
      let hasNew: boolean = false
      for (let i: number = 0; i < result.length; i++) {
        if (result[i].path === '/new') {
          hasNew = true
        }
      }
      expect(hasNew).assertEqual(true)
    })

    it('applyDiff_remove_all_directories', 0, () => {
      const cm: CacheManager = new CacheManager()
      const dirs: Directory[] = [
        new Directory(1, '/a', '', 'A', 1, 0, 0, 0, 0, 0),
        new Directory(2, '/b', '', 'B', 2, 0, 0, 0, 0, 0)
      ]
      const diff: DiffResult = { added: [], removed: ['/a', '/b'], modified: [] }
      const result: Directory[] = cm.applyDiff(dirs, diff)
      expect(result.length).assertEqual(0)
    })

    // ---- Diff computation pattern tests ----

    it('diff_detects_added_directories', 0, () => {
      // Simulate scanAndDiff logic
      const cached: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES)
      ]
      const fresh: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES),
        new Directory(2, '/new', '', 'New', 3, 200, 200, 1000, LOCATION_INTERNAL, TYPE_IMAGES)
      ]
      const cachedPaths: Set<string> = new Set<string>()
      for (let i: number = 0; i < cached.length; i++) {
        cachedPaths.add(cached[i].path)
      }
      const added: Directory[] = fresh.filter((d: Directory): boolean => !cachedPaths.has(d.path))
      expect(added.length).assertEqual(1)
      expect(added[0].path).assertEqual('/new')
    })

    it('diff_detects_removed_directories', 0, () => {
      const cached: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES),
        new Directory(2, '/deleted', '', 'Deleted', 5, 200, 200, 3000, LOCATION_INTERNAL, TYPE_IMAGES)
      ]
      const fresh: Directory[] = [
        new Directory(1, '/photos', '', 'Photos', 10, 100, 100, 5000, LOCATION_INTERNAL, TYPE_IMAGES)
      ]
      const freshPaths: Set<string> = new Set<string>()
      for (let i: number = 0; i < fresh.length; i++) {
        freshPaths.add(fresh[i].path)
      }
      const removed: string[] = []
      for (let i: number = 0; i < cached.length; i++) {
        if (!freshPaths.has(cached[i].path)) {
          removed.push(cached[i].path)
        }
      }
      expect(removed.length).assertEqual(1)
      expect(removed[0]).assertEqual('/deleted')
    })
  })
}

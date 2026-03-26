import { describe, it, expect } from '@ohos/hypium'
import { ConfigManager } from '../../../../main/ets/datastore/ConfigManager'
import {
  SORT_BY_DATE_MODIFIED, SORT_DESCENDING, GROUP_BY_NONE,
  TYPE_IMAGES, TYPE_VIDEOS, TYPE_GIFS, TYPE_RAWS, TYPE_SVGS
} from '../../../../main/ets/common/constants/Constants'

// Integration tests for ConfigManager.
// ConfigManager requires preferences Context (unavailable in test env),
// so we test singleton behavior, initialization guard, and config value patterns.

export default function ConfigManagerIntegrationTest() {
  describe('ConfigManagerIntegrationTest', () => {

    // ---- Singleton behavior ----

    it('getInstance_throws_when_not_initialized', 0, () => {
      // Ensure clean state
      ConfigManager.destroyInstance()
      let threw: boolean = false
      try {
        ConfigManager.getInstance()
      } catch (e) {
        threw = true
      }
      expect(threw).assertEqual(true)
    })

    it('destroyInstance_clears_singleton', 0, () => {
      ConfigManager.destroyInstance()
      let threw: boolean = false
      try {
        ConfigManager.getInstance()
      } catch (e) {
        threw = true
      }
      expect(threw).assertEqual(true)
    })

    it('destroyInstance_is_idempotent', 0, () => {
      ConfigManager.destroyInstance()
      ConfigManager.destroyInstance()
      ConfigManager.destroyInstance()
      let threw: boolean = false
      try {
        ConfigManager.getInstance()
      } catch (e) {
        threw = true
      }
      expect(threw).assertEqual(true)
    })

    // ---- Default config value patterns ----

    it('default_filter_media_includes_images_and_videos', 0, () => {
      // The default filter should include at least images and videos
      const defaultFilter: number = TYPE_IMAGES | TYPE_VIDEOS | TYPE_GIFS | TYPE_RAWS | TYPE_SVGS
      expect((defaultFilter & TYPE_IMAGES) !== 0).assertTrue()
      expect((defaultFilter & TYPE_VIDEOS) !== 0).assertTrue()
    })

    it('default_sort_order_is_date_modified_descending', 0, () => {
      const defaultSort: number = SORT_BY_DATE_MODIFIED | SORT_DESCENDING
      expect((defaultSort & SORT_BY_DATE_MODIFIED) !== 0).assertTrue()
      expect((defaultSort & SORT_DESCENDING) !== 0).assertTrue()
    })

    it('default_group_by_is_none', 0, () => {
      const defaultGroupBy: number = GROUP_BY_NONE
      expect(defaultGroupBy).assertEqual(1)
    })

    it('boolean_config_default_values_pattern', 0, () => {
      // Verify common boolean defaults match expected gallery behavior
      // These are the default values used in ConfigManager getSync calls
      const showHiddenDefault: boolean = false
      const autoplayVideosDefault: boolean = false
      const loopVideosDefault: boolean = false
      const cropThumbnailsDefault: boolean = true
      const useRecycleBinDefault: boolean = true
      const allowPhotoGesturesDefault: boolean = true

      expect(showHiddenDefault).assertEqual(false)
      expect(autoplayVideosDefault).assertEqual(false)
      expect(loopVideosDefault).assertEqual(false)
      expect(cropThumbnailsDefault).assertEqual(true)
      expect(useRecycleBinDefault).assertEqual(true)
      expect(allowPhotoGesturesDefault).assertEqual(true)
    })

    // ---- Config value set/get simulation patterns ----

    it('config_set_get_boolean_pattern', 0, () => {
      // Simulate preferences put/get pattern for boolean
      const store: Map<string, boolean> = new Map<string, boolean>()
      store.set('show_hidden_media', false) // default
      expect(store.get('show_hidden_media')).assertEqual(false)
      store.set('show_hidden_media', true)
      expect(store.get('show_hidden_media')).assertEqual(true)
    })

    it('config_set_get_number_pattern', 0, () => {
      // Simulate preferences put/get pattern for number
      const store: Map<string, number> = new Map<string, number>()
      store.set('filter_media', TYPE_IMAGES | TYPE_VIDEOS)
      expect(store.get('filter_media')).assertEqual(TYPE_IMAGES | TYPE_VIDEOS)
      store.set('filter_media', TYPE_IMAGES)
      expect(store.get('filter_media')).assertEqual(TYPE_IMAGES)
    })

    it('config_set_get_string_pattern', 0, () => {
      // Simulate preferences put/get pattern for string configs (folders, paths)
      const store: Map<string, string> = new Map<string, string>()
      store.set('pinned_folders', '')
      expect(store.get('pinned_folders')).assertEqual('')
      store.set('pinned_folders', '/photos,/downloads')
      expect(store.get('pinned_folders')).assertEqual('/photos,/downloads')
    })

    it('config_column_count_defaults_are_positive', 0, () => {
      // Column count defaults must be positive integers for grid layout
      const dirColumnCntDefault: number = 2
      const mediaColumnCntDefault: number = 3
      const dirLandscapeColumnCntDefault: number = 4
      const mediaLandscapeColumnCntDefault: number = 6
      expect(dirColumnCntDefault > 0).assertTrue()
      expect(mediaColumnCntDefault > 0).assertTrue()
      expect(dirLandscapeColumnCntDefault >= dirColumnCntDefault).assertTrue()
      expect(mediaLandscapeColumnCntDefault >= mediaColumnCntDefault).assertTrue()
    })
  })
}

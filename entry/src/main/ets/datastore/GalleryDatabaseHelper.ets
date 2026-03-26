import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'GalleryDatabaseHelper';
const DOMAIN: number = 0x0000;
const DB_VERSION: number = 1;

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'gallery.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CREATE_MEDIA: string =
  'CREATE TABLE IF NOT EXISTS media (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'filename TEXT NOT NULL, ' +
  'full_path TEXT NOT NULL, ' +
  'parent_path TEXT NOT NULL, ' +
  'last_modified INTEGER NOT NULL DEFAULT 0, ' +
  'date_taken INTEGER NOT NULL DEFAULT 0, ' +
  'size INTEGER NOT NULL DEFAULT 0, ' +
  'type INTEGER NOT NULL DEFAULT 0, ' +
  'video_duration INTEGER NOT NULL DEFAULT 0, ' +
  'is_favorite INTEGER NOT NULL DEFAULT 0, ' +
  'deleted_ts INTEGER NOT NULL DEFAULT 0, ' +
  'media_store_id INTEGER NOT NULL DEFAULT 0' +
  ')';

const SQL_CREATE_DIRECTORIES: string =
  'CREATE TABLE IF NOT EXISTS directories (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'path TEXT NOT NULL, ' +
  'thumbnail TEXT NOT NULL DEFAULT \'\', ' +
  'filename TEXT NOT NULL DEFAULT \'\', ' +
  'media_count INTEGER NOT NULL DEFAULT 0, ' +
  'last_modified INTEGER NOT NULL DEFAULT 0, ' +
  'date_taken INTEGER NOT NULL DEFAULT 0, ' +
  'size INTEGER NOT NULL DEFAULT 0, ' +
  'location INTEGER NOT NULL DEFAULT 0, ' +
  'media_types INTEGER NOT NULL DEFAULT 0, ' +
  'sort_value TEXT NOT NULL DEFAULT \'\'' +
  ')';

const SQL_CREATE_FAVORITES: string =
  'CREATE TABLE IF NOT EXISTS favorites (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'full_path TEXT NOT NULL, ' +
  'filename TEXT NOT NULL DEFAULT \'\', ' +
  'parent_path TEXT NOT NULL DEFAULT \'\'' +
  ')';

const SQL_CREATE_DATE_TAKENS: string =
  'CREATE TABLE IF NOT EXISTS date_takens (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'full_path TEXT NOT NULL, ' +
  'filename TEXT NOT NULL DEFAULT \'\', ' +
  'parent_path TEXT NOT NULL DEFAULT \'\', ' +
  'date_taken INTEGER NOT NULL DEFAULT 0, ' +
  'last_fixed INTEGER NOT NULL DEFAULT 0, ' +
  'last_modified INTEGER NOT NULL DEFAULT 0' +
  ')';

const SQL_CREATE_WIDGETS: string =
  'CREATE TABLE IF NOT EXISTS widgets (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'widget_id INTEGER NOT NULL, ' +
  'folder_path TEXT NOT NULL DEFAULT \'\'' +
  ')';

const SQL_CREATE_INDEX_MEDIA: string =
  'CREATE UNIQUE INDEX IF NOT EXISTS index_media_full_path ON media (full_path)';

const SQL_CREATE_INDEX_DIRECTORIES: string =
  'CREATE UNIQUE INDEX IF NOT EXISTS index_directories_path ON directories (path)';

const SQL_CREATE_INDEX_FAVORITES: string =
  'CREATE UNIQUE INDEX IF NOT EXISTS index_favorites_full_path ON favorites (full_path)';

const SQL_CREATE_INDEX_DATE_TAKENS: string =
  'CREATE UNIQUE INDEX IF NOT EXISTS index_date_takens_full_path ON date_takens (full_path)';

const SQL_CREATE_INDEX_WIDGETS: string =
  'CREATE UNIQUE INDEX IF NOT EXISTS index_widgets_widget_id ON widgets (widget_id)';

export class GalleryDatabaseHelper {
  private static instance: GalleryDatabaseHelper | null = null;
  private rdbStore: relationalStore.RdbStore | null = null;

  private constructor(store: relationalStore.RdbStore) {
    this.rdbStore = store;
  }

  static async initialize(context: common.Context): Promise<void> {
    if (GalleryDatabaseHelper.instance !== null) {
      hilog.warn(DOMAIN, TAG, 'GalleryDatabaseHelper already initialized');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Initializing gallery database...');

    try {
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);

      await store.executeSql(SQL_CREATE_MEDIA);
      await store.executeSql(SQL_CREATE_DIRECTORIES);
      await store.executeSql(SQL_CREATE_FAVORITES);
      await store.executeSql(SQL_CREATE_DATE_TAKENS);
      await store.executeSql(SQL_CREATE_WIDGETS);

      await store.executeSql(SQL_CREATE_INDEX_MEDIA);
      await store.executeSql(SQL_CREATE_INDEX_DIRECTORIES);
      await store.executeSql(SQL_CREATE_INDEX_FAVORITES);
      await store.executeSql(SQL_CREATE_INDEX_DATE_TAKENS);
      await store.executeSql(SQL_CREATE_INDEX_WIDGETS);

      GalleryDatabaseHelper.instance = new GalleryDatabaseHelper(store);

      hilog.info(DOMAIN, TAG, 'Gallery database initialized successfully (version %{public}d)', DB_VERSION);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize gallery database: %{public}s', (e as Error).message);
      throw (e instanceof Error) ? e : new Error(String(e));
    }
  }

  static getInstance(): GalleryDatabaseHelper {
    if (GalleryDatabaseHelper.instance === null) {
      throw new Error('GalleryDatabaseHelper not initialized. Call initialize() in EntryAbility first.');
    }
    return GalleryDatabaseHelper.instance;
  }

  getRdbStore(): relationalStore.RdbStore {
    if (this.rdbStore === null) {
      throw new Error('RdbStore is null. Database may have been destroyed.');
    }
    return this.rdbStore;
  }

  static destroyInstance(): void {
    if (GalleryDatabaseHelper.instance !== null) {
      GalleryDatabaseHelper.instance.rdbStore = null;
      GalleryDatabaseHelper.instance = null;
      hilog.info(DOMAIN, TAG, 'GalleryDatabaseHelper instance destroyed');
    }
  }
}

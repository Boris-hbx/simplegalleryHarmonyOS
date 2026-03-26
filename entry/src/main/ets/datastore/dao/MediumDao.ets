import { relationalStore } from '@kit.ArkData';
import { Medium } from '../../common/models/Medium';
import { GalleryDatabaseHelper } from '../GalleryDatabaseHelper';

const MEDIA_COLUMNS: string = 'filename, full_path, parent_path, last_modified, date_taken, size, type, video_duration, is_favorite, deleted_ts, media_store_id';

export class MediumDao {
  private static instance: MediumDao | null = null;

  private constructor() {
  }

  static getInstance(): MediumDao {
    if (MediumDao.instance === null) {
      MediumDao.instance = new MediumDao();
    }
    return MediumDao.instance;
  }

  private getStore(): relationalStore.RdbStore {
    return GalleryDatabaseHelper.getInstance().getRdbStore();
  }

  private mapRowToMedium(resultSet: relationalStore.ResultSet): Medium {
    try {
      const filename: string = resultSet.getString(resultSet.getColumnIndex('filename'));
      const fullPath: string = resultSet.getString(resultSet.getColumnIndex('full_path'));
      const parentPath: string = resultSet.getString(resultSet.getColumnIndex('parent_path'));
      const lastModified: number = resultSet.getLong(resultSet.getColumnIndex('last_modified'));
      const dateTaken: number = resultSet.getLong(resultSet.getColumnIndex('date_taken'));
      const size: number = resultSet.getLong(resultSet.getColumnIndex('size'));
      const type: number = resultSet.getLong(resultSet.getColumnIndex('type'));
      const videoDuration: number = resultSet.getLong(resultSet.getColumnIndex('video_duration'));
      const isFavoriteInt: number = resultSet.getLong(resultSet.getColumnIndex('is_favorite'));
      const deletedTs: number = resultSet.getLong(resultSet.getColumnIndex('deleted_ts'));
      const mediaStoreId: number = resultSet.getLong(resultSet.getColumnIndex('media_store_id'));

      return new Medium(
        0,
        filename,
        fullPath,
        parentPath,
        lastModified,
        dateTaken,
        size,
        type,
        videoDuration,
        isFavoriteInt === 1,
        deletedTs,
        mediaStoreId
      );
    } catch (e) {
      throw new Error('Failed to map row to Medium: ' + (e as Error).message);
    }
  }

  private mediumToValuesBucket(medium: Medium): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {};
    bucket['filename'] = medium.name;
    bucket['full_path'] = medium.path;
    bucket['parent_path'] = medium.parentPath;
    bucket['last_modified'] = medium.modified;
    bucket['date_taken'] = medium.taken;
    bucket['size'] = medium.size;
    bucket['type'] = medium.type;
    bucket['video_duration'] = medium.videoDuration;
    bucket['is_favorite'] = medium.isFavorite ? 1 : 0;
    bucket['deleted_ts'] = medium.deletedTS;
    bucket['media_store_id'] = medium.mediaStoreId;
    return bucket;
  }

  async getMediaFromPath(path: string): Promise<Array<Medium>> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = `SELECT ${MEDIA_COLUMNS} FROM media WHERE deleted_ts = 0 AND parent_path = ? COLLATE NOCASE`;
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [path]);
      const media: Array<Medium> = [];
      try {
        while (resultSet.goToNextRow()) {
          media.push(this.mapRowToMedium(resultSet));
        }
      } finally {
        resultSet.close();
      }
      return media;
    } catch (e) {
      throw new Error('Failed to get media from path: ' + (e as Error).message);
    }
  }

  async getFavorites(): Promise<Array<Medium>> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = `SELECT ${MEDIA_COLUMNS} FROM media WHERE deleted_ts = 0 AND is_favorite = 1`;
      const resultSet: relationalStore.ResultSet = await store.querySql(sql);
      const media: Array<Medium> = [];
      try {
        while (resultSet.goToNextRow()) {
          media.push(this.mapRowToMedium(resultSet));
        }
      } finally {
        resultSet.close();
      }
      return media;
    } catch (e) {
      throw new Error('Failed to get favorites: ' + (e as Error).message);
    }
  }

  async getFavoritesCount(): Promise<number> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = 'SELECT COUNT(filename) AS cnt FROM media WHERE deleted_ts = 0 AND is_favorite = 1';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql);
      let count: number = 0;
      try {
        if (resultSet.goToNextRow()) {
          count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
        }
      } finally {
        resultSet.close();
      }
      return count;
    } catch (e) {
      throw new Error('Failed to get favorites count: ' + (e as Error).message);
    }
  }

  async getDeletedMedia(): Promise<Array<Medium>> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = `SELECT ${MEDIA_COLUMNS} FROM media WHERE deleted_ts != 0`;
      const resultSet: relationalStore.ResultSet = await store.querySql(sql);
      const media: Array<Medium> = [];
      try {
        while (resultSet.goToNextRow()) {
          media.push(this.mapRowToMedium(resultSet));
        }
      } finally {
        resultSet.close();
      }
      return media;
    } catch (e) {
      throw new Error('Failed to get deleted media: ' + (e as Error).message);
    }
  }

  async getDeletedMediaCount(): Promise<number> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = 'SELECT COUNT(filename) AS cnt FROM media WHERE deleted_ts != 0';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql);
      let count: number = 0;
      try {
        if (resultSet.goToNextRow()) {
          count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
        }
      } finally {
        resultSet.close();
      }
      return count;
    } catch (e) {
      throw new Error('Failed to get deleted media count: ' + (e as Error).message);
    }
  }

  async getOldRecycleBinItems(timestamp: number): Promise<Array<Medium>> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = `SELECT ${MEDIA_COLUMNS} FROM media WHERE deleted_ts < ? AND deleted_ts != 0`;
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [timestamp.toString()]);
      const media: Array<Medium> = [];
      try {
        while (resultSet.goToNextRow()) {
          media.push(this.mapRowToMedium(resultSet));
        }
      } finally {
        resultSet.close();
      }
      return media;
    } catch (e) {
      throw new Error('Failed to get old recycle bin items: ' + (e as Error).message);
    }
  }

  async insert(medium: Medium): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string =
        'INSERT OR REPLACE INTO media (filename, full_path, parent_path, last_modified, date_taken, size, type, video_duration, is_favorite, deleted_ts, media_store_id) ' +
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
      await store.executeSql(sql, [
        medium.name,
        medium.path,
        medium.parentPath,
        medium.modified,
        medium.taken,
        medium.size,
        medium.type,
        medium.videoDuration,
        medium.isFavorite ? 1 : 0,
        medium.deletedTS,
        medium.mediaStoreId
      ]);
    } catch (e) {
      throw new Error('Failed to insert medium: ' + (e as Error).message);
    }
  }

  async insertAll(media: Array<Medium>): Promise<void> {
    const store: relationalStore.RdbStore = this.getStore();
    const sql: string =
      'INSERT OR REPLACE INTO media (filename, full_path, parent_path, last_modified, date_taken, size, type, video_duration, is_favorite, deleted_ts, media_store_id) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    try {
      await store.beginTransaction();
    } catch (e) {
      throw new Error('Failed to begin transaction: ' + (e as Error).message);
    }
    try {
      for (let i: number = 0; i < media.length; i++) {
        const medium: Medium = media[i];
        await store.executeSql(sql, [
          medium.name,
          medium.path,
          medium.parentPath,
          medium.modified,
          medium.taken,
          medium.size,
          medium.type,
          medium.videoDuration,
          medium.isFavorite ? 1 : 0,
          medium.deletedTS,
          medium.mediaStoreId
        ]);
      }
      await store.commit();
    } catch (e) {
      await store.rollBack();
      if (e instanceof Error) {
        throw e;
      }
      throw new Error(String(e));
    }
  }

  async deleteMediumPath(path: string): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = 'DELETE FROM media WHERE full_path = ? COLLATE NOCASE';
      await store.executeSql(sql, [path]);
    } catch (e) {
      throw new Error('Failed to delete medium path: ' + (e as Error).message);
    }
  }

  async updateMedium(oldPath: string, newParentPath: string, newFilename: string, newFullPath: string): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = 'UPDATE OR REPLACE media SET filename = ?, full_path = ?, parent_path = ? WHERE full_path = ? COLLATE NOCASE';
      await store.executeSql(sql, [newFilename, newFullPath, newParentPath, oldPath]);
    } catch (e) {
      throw new Error('Failed to update medium: ' + (e as Error).message);
    }
  }

  async updateDeleted(newPath: string, deletedTS: number, oldPath: string): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = 'UPDATE OR REPLACE media SET full_path = ?, deleted_ts = ? WHERE full_path = ? COLLATE NOCASE';
      await store.executeSql(sql, [newPath, deletedTS, oldPath]);
    } catch (e) {
      throw new Error('Failed to update deleted: ' + (e as Error).message);
    }
  }

  async updateFavoriteDateTaken(path: string, dateTaken: number): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = 'UPDATE media SET date_taken = ? WHERE full_path = ? COLLATE NOCASE';
      await store.executeSql(sql, [dateTaken, path]);
    } catch (e) {
      throw new Error('Failed to update favorite date taken: ' + (e as Error).message);
    }
  }

  async updateFavorite(path: string, isFavorite: boolean): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const favoriteValue: number = isFavorite ? 1 : 0;
      const sql: string = 'UPDATE media SET is_favorite = ? WHERE full_path = ? COLLATE NOCASE';
      await store.executeSql(sql, [favoriteValue, path]);
    } catch (e) {
      throw new Error('Failed to update favorite: ' + (e as Error).message);
    }
  }

  async clearFavorites(): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = 'UPDATE media SET is_favorite = 0';
      await store.executeSql(sql);
    } catch (e) {
      throw new Error('Failed to clear favorites: ' + (e as Error).message);
    }
  }

  async clearRecycleBin(): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getStore();
      const sql: string = 'DELETE FROM media WHERE deleted_ts != 0';
      await store.executeSql(sql);
    } catch (e) {
      throw new Error('Failed to clear recycle bin: ' + (e as Error).message);
    }
  }
}

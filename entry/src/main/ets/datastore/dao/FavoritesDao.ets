import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Favorite } from '../../common/models/Favorite';
import { GalleryDatabaseHelper } from '../GalleryDatabaseHelper';

const TAG: string = 'FavoritesDao';
const DOMAIN: number = 0x0000;
const TABLE_NAME: string = 'favorites';

export class FavoritesDao {
  private getRdbStore(): relationalStore.RdbStore {
    return GalleryDatabaseHelper.getInstance().getRdbStore();
  }

  async insert(favorite: Favorite): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getRdbStore();
      const sql: string =
        'INSERT OR REPLACE INTO favorites (full_path, filename, parent_path) VALUES (?, ?, ?)';
      const bindArgs: Array<relationalStore.ValueType> = [
        favorite.fullPath,
        favorite.filename,
        favorite.parentPath
      ];
      await store.executeSql(sql, bindArgs);
      hilog.debug(DOMAIN, TAG, 'Inserted favorite: %{public}s', favorite.fullPath);
    } catch (e) {
      throw new Error('Failed to insert favorite: ' + (e as Error).message);
    }
  }

  async insertAll(favorites: Array<Favorite>): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getRdbStore();
      const sql: string =
        'INSERT OR REPLACE INTO favorites (full_path, filename, parent_path) VALUES (?, ?, ?)';
      for (let i: number = 0; i < favorites.length; i++) {
        const fav: Favorite = favorites[i];
        const bindArgs: Array<relationalStore.ValueType> = [
          fav.fullPath,
          fav.filename,
          fav.parentPath
        ];
        await store.executeSql(sql, bindArgs);
      }
      hilog.debug(DOMAIN, TAG, 'Inserted %{public}d favorites', favorites.length);
    } catch (e) {
      throw new Error('Failed to insert all favorites: ' + (e as Error).message);
    }
  }

  async getValidFavoritePaths(): Promise<Array<string>> {
    try {
      const store: relationalStore.RdbStore = this.getRdbStore();
      const sql: string =
        'SELECT favorites.full_path FROM favorites INNER JOIN media ON favorites.full_path = media.full_path WHERE media.deleted_ts = 0';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql);
      const paths: Array<string> = [];
      try {
        while (resultSet.goToNextRow()) {
          const fullPath: string = resultSet.getString(resultSet.getColumnIndex('full_path'));
          paths.push(fullPath);
        }
      } finally {
        resultSet.close();
      }
      hilog.debug(DOMAIN, TAG, 'Found %{public}d valid favorite paths', paths.length);
      return paths;
    } catch (e) {
      throw new Error('Failed to get valid favorite paths: ' + (e as Error).message);
    }
  }

  async isFavorite(path: string): Promise<boolean> {
    try {
      const store: relationalStore.RdbStore = this.getRdbStore();
      const sql: string = 'SELECT id FROM favorites WHERE full_path = ? COLLATE NOCASE';
      const bindArgs: Array<relationalStore.ValueType> = [path];
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, bindArgs);
      let found: boolean = false;
      try {
        found = resultSet.goToNextRow();
      } finally {
        resultSet.close();
      }
      return found;
    } catch (e) {
      throw new Error('Failed to check favorite: ' + (e as Error).message);
    }
  }

  async updateFavorite(
    newFilename: string,
    newFullPath: string,
    newParentPath: string,
    oldPath: string
  ): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getRdbStore();
      const sql: string =
        'UPDATE OR REPLACE favorites SET filename = ?, full_path = ?, parent_path = ? WHERE full_path = ? COLLATE NOCASE';
      const bindArgs: Array<relationalStore.ValueType> = [
        newFilename,
        newFullPath,
        newParentPath,
        oldPath
      ];
      await store.executeSql(sql, bindArgs);
      hilog.debug(DOMAIN, TAG, 'Updated favorite from %{public}s to %{public}s', oldPath, newFullPath);
    } catch (e) {
      throw new Error('Failed to update favorite: ' + (e as Error).message);
    }
  }

  async deleteFavoritePath(path: string): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getRdbStore();
      const sql: string = 'DELETE FROM favorites WHERE full_path = ? COLLATE NOCASE';
      const bindArgs: Array<relationalStore.ValueType> = [path];
      await store.executeSql(sql, bindArgs);
      hilog.debug(DOMAIN, TAG, 'Deleted favorite: %{public}s', path);
    } catch (e) {
      throw new Error('Failed to delete favorite path: ' + (e as Error).message);
    }
  }

  async clearFavorites(): Promise<void> {
    try {
      const store: relationalStore.RdbStore = this.getRdbStore();
      await store.executeSql('DELETE FROM favorites');
      hilog.debug(DOMAIN, TAG, 'Cleared all favorites');
    } catch (e) {
      throw new Error('Failed to clear favorites: ' + (e as Error).message);
    }
  }
}

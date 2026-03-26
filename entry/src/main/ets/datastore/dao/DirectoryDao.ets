import { relationalStore } from '@kit.ArkData';
import { Directory } from '../../common/models/Directory';
import { GalleryDatabaseHelper } from '../GalleryDatabaseHelper';
import { RECYCLE_BIN } from '../../common/constants/Constants';

const TABLE_NAME: string = 'directories';

function mapRowToDirectory(resultSet: relationalStore.ResultSet): Directory {
  try {
    const id: number = resultSet.getLong(resultSet.getColumnIndex('id'));
    const path: string = resultSet.getString(resultSet.getColumnIndex('path'));
    const thumbnail: string = resultSet.getString(resultSet.getColumnIndex('thumbnail'));
    const filename: string = resultSet.getString(resultSet.getColumnIndex('filename'));
    const mediaCount: number = resultSet.getLong(resultSet.getColumnIndex('media_count'));
    const lastModified: number = resultSet.getLong(resultSet.getColumnIndex('last_modified'));
    const dateTaken: number = resultSet.getLong(resultSet.getColumnIndex('date_taken'));
    const size: number = resultSet.getLong(resultSet.getColumnIndex('size'));
    const location: number = resultSet.getLong(resultSet.getColumnIndex('location'));
    const mediaTypes: number = resultSet.getLong(resultSet.getColumnIndex('media_types'));
    const sortValue: string = resultSet.getString(resultSet.getColumnIndex('sort_value'));
    return new Directory(id, path, thumbnail, filename, mediaCount, lastModified, dateTaken, size, location, mediaTypes, sortValue);
  } catch (e) {
    throw new Error('Failed to map row to Directory: ' + (e as Error).message);
  }
}

function directoryToValuesBucket(directory: Directory): relationalStore.ValuesBucket {
  const bucket: relationalStore.ValuesBucket = {
    'path': directory.path,
    'thumbnail': directory.tmb,
    'filename': directory.name,
    'media_count': directory.mediaCnt,
    'last_modified': directory.modified,
    'date_taken': directory.taken,
    'size': directory.size,
    'location': directory.location,
    'media_types': directory.types,
    'sort_value': directory.sortValue,
  };
  return bucket;
}

export class DirectoryDao {
  private rdbStore: relationalStore.RdbStore;

  constructor() {
    this.rdbStore = GalleryDatabaseHelper.getInstance().getRdbStore();
  }

  async getAll(): Promise<Array<Directory>> {
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NAME);
      const columns: Array<string> = [
        'id', 'path', 'thumbnail', 'filename', 'media_count',
        'last_modified', 'date_taken', 'size', 'location', 'media_types', 'sort_value'
      ];
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates, columns);
      const directories: Array<Directory> = [];
      try {
        while (resultSet.goToNextRow()) {
          const directory: Directory = mapRowToDirectory(resultSet);
          directories.push(directory);
        }
      } finally {
        resultSet.close();
      }
      return directories;
    } catch (e) {
      throw new Error('Failed to get all directories: ' + (e as Error).message);
    }
  }

  async insert(directory: Directory): Promise<void> {
    try {
      const sql: string =
        'INSERT OR REPLACE INTO ' + TABLE_NAME +
        ' (path, thumbnail, filename, media_count, last_modified, date_taken, size, location, media_types, sort_value)' +
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
      const bindArgs: Array<relationalStore.ValueType> = [
        directory.path, directory.tmb, directory.name, directory.mediaCnt,
        directory.modified, directory.taken, directory.size,
        directory.location, directory.types, directory.sortValue
      ];
      await this.rdbStore.executeSql(sql, bindArgs);
    } catch (e) {
      throw new Error('Failed to insert directory: ' + (e as Error).message);
    }
  }

  async insertAll(directories: Array<Directory>): Promise<void> {
    try {
      const sql: string =
        'INSERT OR REPLACE INTO ' + TABLE_NAME +
        ' (path, thumbnail, filename, media_count, last_modified, date_taken, size, location, media_types, sort_value)' +
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
      for (let i: number = 0; i < directories.length; i++) {
        const directory: Directory = directories[i];
        const bindArgs: Array<relationalStore.ValueType> = [
          directory.path, directory.tmb, directory.name, directory.mediaCnt,
          directory.modified, directory.taken, directory.size,
          directory.location, directory.types, directory.sortValue
        ];
        await this.rdbStore.executeSql(sql, bindArgs);
      }
    } catch (e) {
      throw new Error('Failed to insert all directories: ' + (e as Error).message);
    }
  }

  async deleteDirPath(path: string): Promise<void> {
    try {
      const sql: string = 'DELETE FROM ' + TABLE_NAME + ' WHERE path = ? COLLATE NOCASE';
      const bindArgs: Array<relationalStore.ValueType> = [path];
      await this.rdbStore.executeSql(sql, bindArgs);
    } catch (e) {
      throw new Error('Failed to delete directory path: ' + (e as Error).message);
    }
  }

  async updateDirectory(
    path: string,
    thumbnail: string,
    mediaCnt: number,
    lastModified: number,
    dateTaken: number,
    size: number,
    mediaTypes: number,
    sortValue: string
  ): Promise<void> {
    try {
      const sql: string =
        'UPDATE OR REPLACE ' + TABLE_NAME +
        ' SET thumbnail = ?, media_count = ?, last_modified = ?, date_taken = ?, size = ?, media_types = ?, sort_value = ?' +
        ' WHERE path = ? COLLATE NOCASE';
      const bindArgs: Array<relationalStore.ValueType> = [
        thumbnail, mediaCnt, lastModified, dateTaken, size, mediaTypes, sortValue, path
      ];
      await this.rdbStore.executeSql(sql, bindArgs);
    } catch (e) {
      throw new Error('Failed to update directory: ' + (e as Error).message);
    }
  }

  async updateDirectoryAfterRename(
    thumbnail: string,
    name: string,
    newPath: string,
    oldPath: string
  ): Promise<void> {
    try {
      const sql: string =
        'UPDATE ' + TABLE_NAME +
        ' SET thumbnail = ?, filename = ?, path = ?' +
        ' WHERE path = ? COLLATE NOCASE';
      const bindArgs: Array<relationalStore.ValueType> = [thumbnail, name, newPath, oldPath];
      await this.rdbStore.executeSql(sql, bindArgs);
    } catch (e) {
      throw new Error('Failed to update directory after rename: ' + (e as Error).message);
    }
  }

  async deleteRecycleBin(): Promise<void> {
    try {
      const sql: string = 'DELETE FROM ' + TABLE_NAME + ' WHERE path = ? COLLATE NOCASE';
      const bindArgs: Array<relationalStore.ValueType> = [RECYCLE_BIN];
      await this.rdbStore.executeSql(sql, bindArgs);
    } catch (e) {
      throw new Error('Failed to delete recycle bin: ' + (e as Error).message);
    }
  }

  async getDirectoryThumbnail(path: string): Promise<string | null> {
    try {
      const sql: string = 'SELECT thumbnail FROM ' + TABLE_NAME + ' WHERE path = ?';
      const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql(sql, [path]);
      try {
        if (resultSet.goToNextRow()) {
          const thumbnail: string = resultSet.getString(resultSet.getColumnIndex('thumbnail'));
          return thumbnail;
        }
        return null;
      } finally {
        resultSet.close();
      }
    } catch (e) {
      throw new Error('Failed to get directory thumbnail: ' + (e as Error).message);
    }
  }
}

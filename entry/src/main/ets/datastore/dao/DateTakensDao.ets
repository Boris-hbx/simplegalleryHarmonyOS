import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateTaken } from '../../common/models/DateTaken';
import { GalleryDatabaseHelper } from '../GalleryDatabaseHelper';

const TAG: string = 'DateTakensDao';
const DOMAIN: number = 0x0000;

export class DateTakensDao {
  private getRdbStore(): relationalStore.RdbStore {
    return GalleryDatabaseHelper.getInstance().getRdbStore();
  }

  async insertAll(dateTakens: Array<DateTaken>): Promise<void> {
    const store: relationalStore.RdbStore = this.getRdbStore();
    const sql: string =
      'INSERT OR REPLACE INTO date_takens (full_path, filename, parent_path, date_taken, last_fixed, last_modified) VALUES (?, ?, ?, ?, ?, ?)';
    for (let i: number = 0; i < dateTakens.length; i++) {
      const dt: DateTaken = dateTakens[i];
      const bindArgs: Array<relationalStore.ValueType> = [
        dt.fullPath,
        dt.filename,
        dt.parentPath,
        dt.dateTaken,
        dt.lastFixed,
        dt.lastModified
      ];
      await store.executeSql(sql, bindArgs);
    }
    hilog.debug(DOMAIN, TAG, 'Inserted %{public}d date takens', dateTakens.length);
  }

  async getDateTakensFromPath(path: string): Promise<Array<DateTaken>> {
    const store: relationalStore.RdbStore = this.getRdbStore();
    const sql: string =
      'SELECT full_path, filename, parent_path, date_taken, last_fixed, last_modified FROM date_takens WHERE parent_path = ? COLLATE NOCASE';
    const bindArgs: Array<relationalStore.ValueType> = [path];
    const resultSet: relationalStore.ResultSet = await store.querySql(sql, bindArgs);
    const results: Array<DateTaken> = [];
    try {
      while (resultSet.goToNextRow()) {
        const dt: DateTaken = new DateTaken(
          0,
          resultSet.getString(resultSet.getColumnIndex('full_path')),
          resultSet.getString(resultSet.getColumnIndex('filename')),
          resultSet.getString(resultSet.getColumnIndex('parent_path')),
          resultSet.getLong(resultSet.getColumnIndex('date_taken')),
          resultSet.getLong(resultSet.getColumnIndex('last_fixed')),
          resultSet.getLong(resultSet.getColumnIndex('last_modified'))
        );
        results.push(dt);
      }
    } finally {
      resultSet.close();
    }
    hilog.debug(DOMAIN, TAG, 'Found %{public}d date takens for path %{public}s', results.length, path);
    return results;
  }

  async getAllDateTakens(): Promise<Array<DateTaken>> {
    const store: relationalStore.RdbStore = this.getRdbStore();
    const sql: string =
      'SELECT full_path, filename, parent_path, date_taken, last_fixed, last_modified FROM date_takens';
    const resultSet: relationalStore.ResultSet = await store.querySql(sql);
    const results: Array<DateTaken> = [];
    try {
      while (resultSet.goToNextRow()) {
        const dt: DateTaken = new DateTaken(
          0,
          resultSet.getString(resultSet.getColumnIndex('full_path')),
          resultSet.getString(resultSet.getColumnIndex('filename')),
          resultSet.getString(resultSet.getColumnIndex('parent_path')),
          resultSet.getLong(resultSet.getColumnIndex('date_taken')),
          resultSet.getLong(resultSet.getColumnIndex('last_fixed')),
          resultSet.getLong(resultSet.getColumnIndex('last_modified'))
        );
        results.push(dt);
      }
    } finally {
      resultSet.close();
    }
    hilog.debug(DOMAIN, TAG, 'Found %{public}d total date takens', results.length);
    return results;
  }
}

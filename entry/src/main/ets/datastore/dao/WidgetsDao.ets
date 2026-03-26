import { relationalStore } from '@kit.ArkData';
import { Widget } from '../../common/models/Widget';
import { GalleryDatabaseHelper } from '../GalleryDatabaseHelper';

const TABLE_NAME: string = 'widgets';
const COLUMN_ID: string = 'id';
const COLUMN_WIDGET_ID: string = 'widget_id';
const COLUMN_FOLDER_PATH: string = 'folder_path';

function mapRowToWidget(resultSet: relationalStore.ResultSet): Widget {
  try {
    const id: number = resultSet.getLong(resultSet.getColumnIndex(COLUMN_ID));
    const widgetId: number = resultSet.getLong(resultSet.getColumnIndex(COLUMN_WIDGET_ID));
    const folderPath: string = resultSet.getString(resultSet.getColumnIndex(COLUMN_FOLDER_PATH));
    return new Widget(id, widgetId, folderPath);
  } catch (e) {
    throw new Error('Failed to map row to Widget: ' + (e as Error).message);
  }
}

export class WidgetsDao {
  private rdbStore: relationalStore.RdbStore;

  constructor() {
    this.rdbStore = GalleryDatabaseHelper.getInstance().getRdbStore();
  }

  async getWidgets(): Promise<Widget[]> {
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NAME);
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      const widgets: Widget[] = [];
      try {
        while (resultSet.goToNextRow()) {
          const widget: Widget = mapRowToWidget(resultSet);
          widgets.push(widget);
        }
      } finally {
        resultSet.close();
      }
      return widgets;
    } catch (e) {
      throw new Error('Failed to get widgets: ' + (e as Error).message);
    }
  }

  async insertOrUpdate(widget: Widget): Promise<number> {
    try {
      const sql: string =
        'INSERT OR REPLACE INTO ' + TABLE_NAME +
        ' (' + COLUMN_WIDGET_ID + ', ' + COLUMN_FOLDER_PATH + ')' +
        ' VALUES (?, ?)';
      const bindArgs: relationalStore.ValueType[] = [widget.widgetId, widget.folderPath];
      const resultSet: relationalStore.ResultSet =
        await this.rdbStore.querySql('SELECT ' + COLUMN_ID + ' FROM ' + TABLE_NAME +
          ' WHERE ' + COLUMN_WIDGET_ID + ' = ?', [widget.widgetId]);
      let rowId: number = -1;
      try {
        if (resultSet.goToNextRow()) {
          rowId = resultSet.getLong(resultSet.getColumnIndex(COLUMN_ID));
        }
      } finally {
        resultSet.close();
      }

      if (rowId >= 0) {
        const valueBucket: relationalStore.ValuesBucket = {};
        valueBucket[COLUMN_WIDGET_ID] = widget.widgetId;
        valueBucket[COLUMN_FOLDER_PATH] = widget.folderPath;
        const updatePredicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NAME);
        updatePredicates.equalTo(COLUMN_ID, rowId);
        await this.rdbStore.update(valueBucket, updatePredicates);
        return rowId;
      } else {
        const valueBucket: relationalStore.ValuesBucket = {};
        valueBucket[COLUMN_WIDGET_ID] = widget.widgetId;
        valueBucket[COLUMN_FOLDER_PATH] = widget.folderPath;
        const insertedRowId: number = await this.rdbStore.insert(TABLE_NAME, valueBucket);
        return insertedRowId;
      }
    } catch (e) {
      throw new Error('Failed to insert or update widget: ' + (e as Error).message);
    }
  }

  async deleteWidgetId(widgetId: number): Promise<void> {
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NAME);
      predicates.equalTo(COLUMN_WIDGET_ID, widgetId);
      await this.rdbStore.delete(predicates);
    } catch (e) {
      throw new Error('Failed to delete widget: ' + (e as Error).message);
    }
  }
}

// =============================================================================
// FavoritesExporter.ets — Export/Import favorite paths as newline-delimited text
// T-057: Export/Import Favorites
// =============================================================================

import { FavoritesDao } from '../../datastore/dao/FavoritesDao'
import { Favorite } from '../models/Favorite'

export class FavoritesExporter {

  static async exportFavorites(): Promise<string> {
    const dao: FavoritesDao = new FavoritesDao()
    const paths: string[] = await dao.getValidFavoritePaths()
    return paths.join('\n')
  }

  static async importFavorites(content: string): Promise<number> {
    const dao: FavoritesDao = new FavoritesDao()
    const lines: string[] = content.split('\n')
    let count: number = 0
    for (let i: number = 0; i < lines.length; i++) {
      const path: string = lines[i].trim()
      if (path.length > 0) {
        // Extract filename and parent path from the full path
        const lastSlash: number = path.lastIndexOf('/')
        const filename: string = lastSlash >= 0 ? path.substring(lastSlash + 1) : path
        const parentPath: string = lastSlash >= 0 ? path.substring(0, lastSlash) : ''
        const favorite: Favorite = new Favorite(0, path, filename, parentPath)
        await dao.insert(favorite)
        count++
      }
    }
    return count
  }
}

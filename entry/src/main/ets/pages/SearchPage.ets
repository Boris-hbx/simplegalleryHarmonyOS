import { router } from '@kit.ArkUI'
import { Medium } from '../common/models/Medium'
import { MediaScanner } from '../media/MediaScanner'
import { ConfigManager } from '../datastore/ConfigManager'
import { MediaItem } from '../components/MediaItem'

interface ViewingPageParams {
  mediaListJson: string
  selectedIndex: number
  folderPath: string
}

@Entry
@Component
struct SearchPage {
  @State searchQuery: string = ''
  @State allMedia: Medium[] = []
  @State filteredMedia: Medium[] = []
  @State isLoading: boolean = true
  @State columnCount: number = 3
  @State displayFileNames: boolean = false

  private debounceTimerId: number = -1

  aboutToAppear(): void {
    const config: ConfigManager = ConfigManager.getInstance()
    this.columnCount = config.mediaColumnCnt
    this.displayFileNames = config.displayFileNames
    this.loadAllMedia()
  }

  onBackPress(): boolean {
    router.back()
    return true
  }

  async loadAllMedia(): Promise<void> {
    this.isLoading = true
    try {
      const scanner: MediaScanner = new MediaScanner(this.getUIContext().getHostContext()!)
      const config: ConfigManager = ConfigManager.getInstance()
      this.allMedia = await scanner.getAllMedia(config.filterMedia)
      this.filteredMedia = this.allMedia
    } catch (e) {
      console.error('SearchPage: Failed to load media')
    }
    this.isLoading = false
  }

  private applyFilter(query: string): void {
    if (query.length === 0) {
      this.filteredMedia = this.allMedia
      return
    }
    const lower: string = query.toLowerCase()
    const results: Medium[] = []
    for (let i: number = 0; i < this.allMedia.length; i++) {
      const m: Medium = this.allMedia[i]
      if (m.name.toLowerCase().includes(lower)) {
        results.push(m)
      }
    }
    // Sort: prefix matches first, then contains-only matches
    results.sort((a: Medium, b: Medium): number => {
      const aStarts: number = a.name.toLowerCase().startsWith(lower) ? 0 : 1
      const bStarts: number = b.name.toLowerCase().startsWith(lower) ? 0 : 1
      return aStarts - bStarts
    })
    this.filteredMedia = results
  }

  private debouncedFilter(query: string): void {
    if (this.debounceTimerId !== -1) {
      clearTimeout(this.debounceTimerId)
    }
    this.debounceTimerId = setTimeout((): void => {
      this.applyFilter(query)
      this.debounceTimerId = -1
    }, 200)
  }

  private navigateToViewing(index: number): void {
    const serialized: Object[] = []
    for (let i: number = 0; i < this.filteredMedia.length; i++) {
      const m: Medium = this.filteredMedia[i]
      const obj: Record<string, Object> = {} as Record<string, Object>
      obj['id'] = m.id
      obj['name'] = m.name
      obj['path'] = m.path
      obj['parentPath'] = m.parentPath
      obj['modified'] = m.modified
      obj['taken'] = m.taken
      obj['size'] = m.size
      obj['type'] = m.type
      obj['videoDuration'] = m.videoDuration
      obj['isFavorite'] = m.isFavorite
      obj['deletedTS'] = m.deletedTS
      obj['mediaStoreId'] = m.mediaStoreId
      serialized.push(obj)
    }

    try {
      const navParams: ViewingPageParams = { mediaListJson: JSON.stringify(serialized), selectedIndex: index, folderPath: '' }
      router.pushUrl({ url: 'pages/ViewingPage', params: navParams })
    } catch (e) {
      console.error('SearchPage: Navigation to ViewingPage failed')
    }
  }

  build() {
    Column() {
      // Title bar with back button
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24)
          .height(24)
          .onClick((): void => {
            router.back()
          })
        Text($r('app.string.search'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 16 })
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // Search input
      Search({ value: this.searchQuery, placeholder: $r('app.string.search_files') })
        .width('100%')
        .padding({ left: 16, right: 16 })
        .onChange((value: string): void => {
          this.searchQuery = value
          this.debouncedFilter(value)
        })
        .onSubmit((value: string): void => {
          if (this.debounceTimerId !== -1) {
            clearTimeout(this.debounceTimerId)
            this.debounceTimerId = -1
          }
          this.applyFilter(value)
        })

      // Content area
      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .margin({ top: 100 })
      } else if (this.filteredMedia.length === 0 && this.searchQuery.length > 0) {
        Column() {
          Text($r('app.string.no_items_found'))
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 100 })
        }
        .width('100%')
        .layoutWeight(1)
      } else if (this.filteredMedia.length === 0) {
        Column() {
          Text($r('app.string.no_media_available'))
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 100 })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Grid() {
          ForEach(this.filteredMedia, (item: Medium, index: number) => {
            GridItem() {
              MediaItem({
                medium: item,
                showFileName: this.displayFileNames
              })
                .onClick((): void => {
                  this.navigateToViewing(index)
                })
            }
          }, (item: Medium, _index: number): string => {
            return item.path
          })
        }
        .columnsTemplate(this.buildColumnsTemplate())
        .columnsGap(2)
        .rowsGap(2)
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  buildColumnsTemplate(): string {
    let template: string = ''
    for (let i: number = 0; i < this.columnCount; i++) {
      if (i > 0) {
        template += ' '
      }
      template += '1fr'
    }
    return template
  }
}

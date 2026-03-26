// =============================================================================
// WidgetCard.ets — Gallery home screen widget card
// Shows latest photo thumbnail; tapping opens the gallery app
// =============================================================================

const widgetStorage: LocalStorage = new LocalStorage()

@Entry(widgetStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('thumbnailUri') thumbnailUri: string = ''
  @LocalStorageProp('folderName') folderName: string = ''
  @LocalStorageProp('showFolderName') showFolderName: boolean = true

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.thumbnailUri.length > 0) {
        Image(this.thumbnailUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(16)
      } else {
        Column() {
          Text('🖼')
            .fontSize(36)
          Text('图库')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#F0F0F0')
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      if (this.showFolderName && this.folderName.length > 0) {
        Text(this.folderName)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor('#80000000')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 6, bottom: 6 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .borderRadius({ bottomLeft: 16, bottomRight: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      // PIT-022: Must use postCardAction for widget interactions
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: {
          targetPage: 'pages/MainPage'
        }
      })
    })
  }
}

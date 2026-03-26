// Base class for grid items — both Medium and ThumbnailSection extend this
export class ThumbnailItem {
}

// Group header displayed in grid view (e.g., "January 2024")
export class ThumbnailSection extends ThumbnailItem {
  title: string

  constructor(title: string) {
    super()
    this.title = title
  }
}

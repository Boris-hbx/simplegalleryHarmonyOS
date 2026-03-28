// =============================================================================
// VideoViewer.ets — Inline video player using AVPlayer with fd source
// BUG-022 fix: Use fileIo.openSync() to open photoAccessHelper URIs
// (file://media/Photo/xxx) and obtain a file descriptor for AVPlayer.
// =============================================================================

import { Medium } from '../common/models/Medium'
import { media } from '@kit.MediaKit'
import { fileIo } from '@kit.CoreFileKit'

@Component
export struct VideoViewer {
  @Prop medium: Medium = new Medium()

  @State isPlaying: boolean = false
  @State playError: boolean = false
  @State errorMessage: string = ''
  @State currentTime: number = 0
  @State totalDuration: number = 0
  @State showControls: boolean = true
  @State isPrepared: boolean = false
  @State surfaceId: string = ''
  // T-073 ①: Video double-tap zoom
  @State videoScale: number = 1.0

  private avPlayer: media.AVPlayer | null = null
  private xComponentController: XComponentController = new XComponentController()
  private file: fileIo.File | null = null
  private controlsTimerId: number = -1

  aboutToAppear(): void {
    this.totalDuration = this.medium.videoDuration
  }

  aboutToDisappear(): void {
    this.releasePlayer()
    if (this.controlsTimerId !== -1) {
      clearTimeout(this.controlsTimerId)
      this.controlsTimerId = -1
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Dark background
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

      // BUG-028 fix: XComponent must always be rendered so onLoad fires immediately
      // and surfaceId is available before AVPlayer.prepare(). Use opacity to hide
      // until prepared. Use mediaStoreId for id to avoid illegal characters from path.
      XComponent({
        id: 'vid_' + Math.abs(this.medium.path.length * 31 + this.medium.size).toString(),
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .width('100%')
        .height('100%')
        .opacity(this.isPrepared ? 1 : 0)
        .onLoad((): void => {
          this.surfaceId = this.xComponentController.getXComponentSurfaceId()
          console.info('[VideoViewer] XComponent onLoad, surfaceId: ' + this.surfaceId)
          // If avPlayer already in initialized state and waiting for surface, set it now
          if (this.avPlayer !== null && !this.isPrepared && this.surfaceId.length > 0) {
            this.setupPlayerSurface()
          }
        })

      // Video thumbnail before player is ready
      if (!this.isPrepared) {
        Image(this.medium.path)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .opacity(0.6)
      }

      // Controls overlay
      if (this.showControls || !this.isPlaying) {
        Column() {
          if (this.playError) {
            // Error state — centered
            Blank()
            Text('Cannot play video')
              .fontSize(16)
              .fontColor('#FF6B6B')
            if (this.errorMessage) {
              Text(this.errorMessage)
                .fontSize(12)
                .fontColor('#AAFFFFFF')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            Blank()
          } else {
            // Spacer to center play button
            Blank()

            // Play/Pause button — centered
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(72)
                .height(72)
                .fill('rgba(255,255,255,0.3)')
              Image(this.isPlaying
                ? $r('sys.media.ohos_ic_public_pause')
                : $r('sys.media.ohos_ic_public_play'))
                .width(36)
                .height(36)
                .fillColor(Color.White)
            }
            .onClick((): void => {
              this.togglePlayback().catch((err: Error): void => {
                console.error('[VideoViewer] togglePlayback error: ' + err.message)
                this.playError = true
                this.errorMessage = err.message
              })
            })

            // Spacer to push progress bar to bottom
            Blank()

            // Progress bar with slider and time labels — always shown
            Row() {
              Text(this.formatTime(this.currentTime))
                .fontSize(12)
                .fontColor(Color.White)
                .margin({ right: 8 })
              Slider({
                value: this.totalDuration > 0 ? this.currentTime / this.totalDuration * 100 : 0,
                min: 0,
                max: 100
              })
                .layoutWeight(1)
                .trackColor('rgba(255,255,255,0.3)')
                .selectedColor(Color.White)
                .onChange((value: number): void => {
                  if (this.avPlayer && this.isPrepared && this.totalDuration > 0) {
                    const seekTime: number = value / 100 * this.totalDuration
                    this.avPlayer.seek(seekTime)
                  }
                })
              Text(this.totalDuration > 0 ? this.formatTime(this.totalDuration) : '--:--')
                .fontSize(12)
                .fontColor(Color.White)
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 16 })
          }
        }
        .width('100%')
        .height('100%')
      }

      // Tap area for showing/hiding controls — only when playing
      if (this.isPlaying && !this.showControls) {
        Column()
          .width('100%')
          .height('100%')
          .onClick((): void => {
            this.showControls = true
            this.resetControlsTimer()
          })
      }
    }
    .width('100%')
    .height('100%')
    // T-073 ①: Double-tap zoom (1x ↔ 2x)
    .scale({ x: this.videoScale, y: this.videoScale })
    .gesture(
      TapGesture({ count: 2 })
        .onAction((): void => {
          if (this.videoScale > 1.5) {
            this.videoScale = 1.0
          } else {
            this.videoScale = 2.0
          }
        })
    )
  }

  private async togglePlayback(): Promise<void> {
    if (this.playError) {
      return
    }

    if (!this.avPlayer) {
      await this.initializePlayer()
      return
    }

    if (this.isPlaying) {
      try {
        await this.avPlayer.pause()
        this.isPlaying = false
      } catch (e) {
        console.error('[VideoViewer] Pause error: ' + (e as Error).message)
      }
    } else {
      try {
        await this.avPlayer.play()
        this.isPlaying = true
        this.resetControlsTimer()
      } catch (e) {
        console.error('[VideoViewer] Play error: ' + (e as Error).message)
      }
    }
  }

  private async initializePlayer(): Promise<void> {
    try {
      // Open the photoAccessHelper URI to get a file descriptor
      console.info('[VideoViewer] Opening URI: ' + this.medium.path)
      this.file = fileIo.openSync(this.medium.path, fileIo.OpenMode.READ_ONLY)
      const fd: number = this.file.fd
      console.info('[VideoViewer] Got fd: ' + fd.toString())

      // Get file size for fdSrc
      let fileSize: number = this.medium.size > 0 ? this.medium.size : 0
      try {
        const stat: fileIo.Stat = fileIo.statSync(fd)
        fileSize = stat.size
        console.info('[VideoViewer] File size from stat: ' + fileSize.toString())
      } catch (statErr) {
        console.warn('[VideoViewer] statSync failed, using medium.size: ' + fileSize.toString())
      }

      // Create AVPlayer
      this.avPlayer = await media.createAVPlayer()

      // Set up state change callback
      this.avPlayer.on('stateChange', (state: string): void => {
        console.info('[VideoViewer] AVPlayer state: ' + state)
        switch (state) {
          case 'initialized':
            // surfaceId may already be available from XComponent.onLoad
            if (this.surfaceId) {
              this.setupPlayerSurface()
            }
            break
          case 'prepared':
            // Ready to play — show video surface and start playback
            this.isPrepared = true
            this.startPlayback()
            break
          case 'playing':
            this.isPlaying = true
            break
          case 'paused':
            this.isPlaying = false
            break
          case 'completed':
            this.isPlaying = false
            this.showControls = true
            this.currentTime = this.totalDuration
            break
          case 'error':
            console.error('[VideoViewer] AVPlayer entered error state')
            this.playError = true
            this.errorMessage = 'Player error'
            break
          default:
            break
        }
      })

      // Set up time update callback
      this.avPlayer.on('timeUpdate', (timeMs: number): void => {
        this.currentTime = timeMs
      })

      // Set up error callback
      this.avPlayer.on('error', (err: Error): void => {
        console.error('[VideoViewer] AVPlayer error: ' + err.message)
        this.playError = true
        this.errorMessage = err.message
      })

      // Set the fd source — fileSize must be > 0
      if (fileSize <= 0) {
        console.error('[VideoViewer] fileSize is 0, cannot set fdSrc')
        this.playError = true
        this.errorMessage = 'Cannot determine file size'
        return
      }
      console.info('[VideoViewer] Setting fdSrc: fd=' + fd.toString() + ' size=' + fileSize.toString())
      this.avPlayer.fdSrc = {
        fd: fd,
        offset: 0,
        length: fileSize
      }
    } catch (e) {
      const errMsg: string = (e as Error).message || 'Unknown error'
      console.error('[VideoViewer] initializePlayer error: ' + errMsg)
      this.playError = true
      this.errorMessage = errMsg
    }
  }

  private setupPlayerSurface(): void {
    if (this.avPlayer && this.surfaceId) {
      try {
        this.avPlayer.surfaceId = this.surfaceId
        this.avPlayer.prepare().catch((err: Error): void => {
          console.error('[VideoViewer] Prepare error: ' + err.message)
          this.playError = true
          this.errorMessage = err.message
        })
      } catch (e) {
        console.error('[VideoViewer] setupPlayerSurface error: ' + (e as Error).message)
      }
    }
  }

  private startPlayback(): void {
    if (this.avPlayer) {
      // Update duration from player if available
      if (this.avPlayer.duration > 0) {
        this.totalDuration = this.avPlayer.duration
      }
      this.avPlayer.play().then((): void => {
        this.isPlaying = true
        this.resetControlsTimer()
      }).catch((err: Error): void => {
        console.error('[VideoViewer] play() error: ' + err.message)
        this.playError = true
        this.errorMessage = err.message
      })
    }
  }

  private resetControlsTimer(): void {
    if (this.controlsTimerId !== -1) {
      clearTimeout(this.controlsTimerId)
    }
    if (this.isPlaying) {
      this.controlsTimerId = setTimeout((): void => {
        this.showControls = false
        this.controlsTimerId = -1
      }, 3000)
    }
  }

  private releasePlayer(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.off('stateChange')
        this.avPlayer.off('timeUpdate')
        this.avPlayer.off('error')
        this.avPlayer.release()
      } catch (e) {
        console.error('[VideoViewer] releasePlayer error: ' + (e as Error).message)
      }
      this.avPlayer = null
    }
    if (this.file) {
      try {
        fileIo.closeSync(this.file)
      } catch (e) {
        console.error('[VideoViewer] closeSync error: ' + (e as Error).message)
      }
      this.file = null
    }
  }

  private formatTime(ms: number): string {
    const totalSeconds: number = Math.floor(ms / 1000)
    const minutes: number = Math.floor(totalSeconds / 60)
    const seconds: number = totalSeconds % 60
    const secStr: string = seconds < 10 ? '0' + seconds.toString() : seconds.toString()
    return minutes.toString() + ':' + secStr
  }
}

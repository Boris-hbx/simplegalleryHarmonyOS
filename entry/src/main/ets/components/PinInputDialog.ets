// =============================================================================
// PinInputDialog.ets — PIN input dialog for folder lock/unlock
// BUG-042-v2: Matches Android SecurityDialog (PIN mode only)
// =============================================================================

import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'

// SHA256 hash a PIN string
function sha256Hash(input: string): string {
  const textEncoder: util.TextEncoder = new util.TextEncoder()
  const encoded: Uint8Array = textEncoder.encodeInto(input)
  const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data: encoded })
  const result: cryptoFramework.DataBlob = md.digestSync()
  const hashArray: Uint8Array = result.data
  let hex: string = ''
  for (let i: number = 0; i < hashArray.length; i++) {
    const byte: number = hashArray[i]
    hex += (byte < 16 ? '0' : '') + byte.toString(16)
  }
  return hex
}

@CustomDialog
export struct PinInputDialog {
  controller: CustomDialogController
  // Mode: 'set' = new PIN (input + confirm), 'verify' = check against hash
  mode: string = 'set'
  // For verify mode: the stored hash to check against
  requiredHash: string = ''
  // Callback: (hash, success) — hash is the SHA256 of entered PIN
  onResult: (hash: string, success: boolean) => void = (_hash: string, _success: boolean) => {}

  @State private pin: string = ''
  @State private confirmPin: string = ''
  @State private isConfirmStep: boolean = false
  @State private errorMsg: string = ''
  @State private failCount: number = 0

  build() {
    Column() {
      Text(this.mode === 'set' ?
        (this.isConfirmStep ? '确认 PIN 码' : '设置 PIN 码') :
        '输入 PIN 码')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 16 })

      if (this.mode === 'set' && !this.isConfirmStep) {
        Text('请输入 4-6 位数字 PIN 码来锁定文件夹')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ bottom: 12 })
      }

      TextInput({ placeholder: 'PIN', text: this.isConfirmStep ? this.confirmPin : this.pin })
        .type(InputType.Password)
        .maxLength(6)
        .width('100%')
        .height(48)
        .onChange((value: string) => {
          if (this.isConfirmStep) {
            this.confirmPin = value
          } else {
            this.pin = value
          }
          this.errorMsg = ''
        })

      if (this.errorMsg.length > 0) {
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor('#E53935')
          .margin({ top: 8 })
      }

      Row() {
        Button('取消')
          .fontColor('#007DFF')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.onResult('', false)
            this.controller.close()
          })
          .layoutWeight(1)

        Button(this.mode === 'set' ?
          (this.isConfirmStep ? '确定' : '下一步') :
          '确定')
          .fontColor(Color.White)
          .backgroundColor('#007DFF')
          .onClick(() => {
            this.handleConfirm()
          })
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .padding(24)
    .width('100%')
  }

  private handleConfirm(): void {
    if (this.mode === 'set') {
      this.handleSetMode()
    } else {
      this.handleVerifyMode()
    }
  }

  private handleSetMode(): void {
    if (!this.isConfirmStep) {
      // Step 1: Enter new PIN
      if (this.pin.length < 4) {
        this.errorMsg = 'PIN 码至少 4 位'
        return
      }
      this.isConfirmStep = true
      this.confirmPin = ''
      this.errorMsg = ''
    } else {
      // Step 2: Confirm PIN
      if (this.confirmPin !== this.pin) {
        this.errorMsg = '两次输入不一致，请重新输入'
        this.confirmPin = ''
        return
      }
      const hash: string = sha256Hash(this.pin)
      this.onResult(hash, true)
      this.controller.close()
    }
  }

  private handleVerifyMode(): void {
    if (this.pin.length < 4) {
      this.errorMsg = 'PIN 码至少 4 位'
      return
    }
    const hash: string = sha256Hash(this.pin)
    if (hash === this.requiredHash) {
      this.onResult(hash, true)
      this.controller.close()
    } else {
      this.failCount++
      this.pin = ''
      if (this.failCount >= 3) {
        this.errorMsg = '密码错误，请稍后重试'
      } else {
        this.errorMsg = '密码错误，请重试 (' + this.failCount.toString() + '/3)'
      }
    }
  }
}

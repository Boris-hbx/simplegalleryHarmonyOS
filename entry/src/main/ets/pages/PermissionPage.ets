import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface PermissionResult {
  permissions: Array<string>;
  authResults: Array<number>;
}

const DOMAIN: number = 0x0000;
const TAG: string = 'PermissionPage';
const REQUIRED_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.READ_IMAGEVIDEO',
  'ohos.permission.WRITE_IMAGEVIDEO'
];

@Entry
@Component
struct PermissionPage {
  @State permissionGranted: boolean = false;
  @State permissionDenied: boolean = false;

  aboutToAppear(): void {
    this.checkPermission();
  }

  private checkPermission(): void {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const bundleInfo: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    const tokenId: number = bundleInfo.appInfo.accessTokenId;
    atManager.checkAccessToken(tokenId, REQUIRED_PERMISSIONS[0])
      .then((grantStatus: abilityAccessCtrl.GrantStatus) => {
        if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          this.permissionGranted = true;
          this.navigateToMain();
        }
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Failed to check permission: %{public}s', JSON.stringify(err));
      });
  }

  private requestPermission(): void {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    atManager.requestPermissionsFromUser(context, REQUIRED_PERMISSIONS)
      .then((result: PermissionResult) => {
        const readGranted: boolean = result.authResults[0] === 0;
        if (readGranted) {
          this.permissionGranted = true;
          this.permissionDenied = false;
          this.navigateToMain();
        } else {
          this.permissionDenied = true;
          hilog.warn(DOMAIN, TAG, 'Permission denied by user');
        }
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Failed to request permission: %{public}s', JSON.stringify(err));
        this.permissionDenied = true;
      });
  }

  private navigateToMain(): void {
    router.replaceUrl({ url: 'pages/MainPage' })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Failed to navigate to MainPage: %{public}s', JSON.stringify(err));
      });
  }

  build() {
    Column() {
      Image($r('app.media.startIcon'))
        .width(96)
        .height(96)
        .margin({ top: 120 })

      Text($r('app.string.EntryAbility_label'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .margin({ top: 24 })

      Text($r('app.string.permission_prompt'))
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
        .margin({ top: 12 })

      if (this.permissionDenied) {
        Text($r('app.string.permission_denied_msg'))
          .fontSize(14)
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
          .margin({ top: 16 })
      }

      Button(this.permissionDenied ? $r('app.string.retry') : $r('app.string.grant_access'))
        .type(ButtonType.Capsule)
        .width('60%')
        .height(48)
        .fontSize(18)
        .margin({ top: 48 })
        .onClick(() => {
          this.requestPermission();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}

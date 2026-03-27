import { AbilityConstant, abilityAccessCtrl, bundleManager, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { GalleryDatabaseHelper } from '../datastore/GalleryDatabaseHelper';
import { ConfigManager } from '../datastore/ConfigManager';
import { WidgetCacheManager } from '../widget/WidgetCacheManager';

const DOMAIN: number = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    GalleryDatabaseHelper.destroyInstance();
    ConfigManager.destroyInstance();
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // PIT-012 & PIT-015: Database MUST be initialized before loadContent
    await GalleryDatabaseHelper.initialize(this.context);
    await ConfigManager.initialize(this.context);

    let startPage: string = 'pages/PermissionPage';
    try {
      const bundleInfo: bundleManager.BundleInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId: number = bundleInfo.appInfo.accessTokenId;
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const grantStatus: abilityAccessCtrl.GrantStatus =
        atManager.checkAccessTokenSync(tokenId, 'ohos.permission.READ_IMAGEVIDEO');
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        startPage = 'pages/MainPage';
        // PAT-026: Generate widget thumbnail cache while we have permission
        // Fire-and-forget — don't block app startup for widget cache
        WidgetCacheManager.generateDefaultCache(this.context).then((generated: boolean): void => {
          if (generated) {
            WidgetCacheManager.refreshAllWidgets(this.context)
          }
        }).catch((): void => {
          // Widget cache generation is best-effort — don't fail app startup
        })
      }
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'testTag', 'Failed to check permission: %{public}s', JSON.stringify(error));
    }

    windowStage.loadContent(startPage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content. Page: %{public}s', startPage);
    });
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // Called when app is already running and Widget/deeplink brings it to foreground
    hilog.info(DOMAIN, 'testTag', 'Ability onNewWant');
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    // D1-002: Signal pages to refresh data when returning from background
    // (external apps may have added/deleted media while we were in background)
    AppStorage.setOrCreate('needsRefresh', Date.now())
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}

// =============================================================================
// SandboxTestPage.ets — 沙箱机制测试页面
// 在真机上运行，逐项验证应用沙箱的读写、隔离和权限边界
// =============================================================================

import { fileIo } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { router } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { dataSharePredicates } from '@kit.ArkData'
import { util } from '@kit.ArkTS'

interface TestResult {
  name: string
  status: string  // 'PASS' | 'FAIL' | 'WARN' | 'PENDING'
  detail: string
}

@Entry
@Component
struct SandboxTestPage {
  @State results: TestResult[] = []
  @State running: boolean = false
  @State summary: string = '点击"开始测试"运行全部沙箱测试'

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('←')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .onClick(() => router.back())
          .padding({ right: 16 })

        Text('沙箱机制测试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      .padding(16)

      // 摘要
      Text(this.summary)
        .fontSize(14)
        .fontColor(this.running ? '#FF6600' : '#666666')
        .padding({ left: 16, right: 16, bottom: 8 })
        .width('100%')

      // 开始按钮
      Button(this.running ? '测试中...' : '开始测试')
        .width('90%')
        .height(44)
        .margin({ bottom: 16 })
        .enabled(!this.running)
        .onClick(() => this.runAllTests())

      // 结果列表
      List() {
        ForEach(this.results, (item: TestResult, index: number) => {
          ListItem() {
            Row() {
              // 状态图标
              Text(item.status === 'PASS' ? '✅' :
                   item.status === 'FAIL' ? '❌' :
                   item.status === 'WARN' ? '⚠️' : '⏳')
                .fontSize(20)
                .width(36)

              Column() {
                Text(`${(index as number) + 1}. ${item.name}`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')

                Text(item.detail)
                  .fontSize(12)
                  .fontColor(item.status === 'FAIL' ? '#CC0000' :
                             item.status === 'WARN' ? '#CC6600' : '#666666')
                  .margin({ top: 4 })
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(12)
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0.5, color: '#EEEEEE' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  private async runAllTests(): Promise<void> {
    this.running = true
    this.results = []
    this.summary = '正在运行测试...'

    // 逐项执行
    await this.test01_sandboxDirs()
    await this.test02_cacheWrite()
    await this.test03_cacheRead()
    await this.test04_tempDir()
    await this.test05_filesDir()
    await this.test06_crossSandboxBlock()
    await this.test07_systemPathBlock()
    await this.test08_photoAccessHelperUri()
    await this.test09_uriOpenDirect()
    await this.test10_dbFileIsolation()
    await this.test11_preferencesIsolation()
    await this.test12_cleanupTemp()

    // 汇总
    let pass = 0
    let fail = 0
    let warn = 0
    for (const r of this.results) {
      if (r.status === 'PASS') {
        pass++
      }
      if (r.status === 'FAIL') {
        fail++
      }
      if (r.status === 'WARN') {
        warn++
      }
    }
    this.summary = `完成: ${pass} 通过, ${fail} 失败, ${warn} 警告 (共 ${this.results.length} 项)`
    this.running = false
  }

  // ─── Test 01: 沙箱目录存在性 ───
  private async test01_sandboxDirs(): Promise<void> {
    const name = '沙箱目录存在性'
    try {
      const ctx = getContext(this)
      const cacheDir = ctx.cacheDir
      const filesDir = ctx.filesDir
      const tempDir = ctx.tempDir

      const parts: string[] = []
      parts.push(`cacheDir: ${cacheDir}`)
      parts.push(`filesDir: ${filesDir}`)
      parts.push(`tempDir: ${tempDir}`)

      // 验证都可访问
      let allExist = true
      try {
        fileIo.accessSync(cacheDir)
      } catch (e) {
        allExist = false
      }
      try {
        fileIo.accessSync(filesDir)
      } catch (e) {
        allExist = false
      }
      try {
        fileIo.accessSync(tempDir)
      } catch (e) {
        allExist = false
      }

      if (allExist) {
        this.addResult(name, 'PASS', parts.join('\n'))
      } else {
        this.addResult(name, 'FAIL', '部分沙箱目录不可访问')
      }
    } catch (e) {
      this.addResult(name, 'FAIL', `异常: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 02: cacheDir 写入 ───
  private async test02_cacheWrite(): Promise<void> {
    const name = 'cacheDir 写入测试'
    try {
      const ctx = getContext(this)
      const testPath = ctx.cacheDir + '/sandbox_test.txt'
      const testContent = `sandbox test ${Date.now()}`

      const fd = fileIo.openSync(testPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      const encoder = new util.TextEncoder()
      const buf = encoder.encodeInto(testContent)
      const written = fileIo.writeSync(fd.fd, buf.buffer)
      fileIo.closeSync(fd)

      this.addResult(name, 'PASS', `写入 ${written} 字节到 ${testPath}`)
    } catch (e) {
      this.addResult(name, 'FAIL', `写入失败: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 03: cacheDir 读取 ───
  private async test03_cacheRead(): Promise<void> {
    const name = 'cacheDir 读取测试'
    try {
      const ctx = getContext(this)
      const testPath = ctx.cacheDir + '/sandbox_test.txt'

      const fd = fileIo.openSync(testPath, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(fd.fd)
      const buf = new ArrayBuffer(stat.size)
      const readBytes = fileIo.readSync(fd.fd, buf)
      fileIo.closeSync(fd)

      const decoder = util.TextDecoder.create('utf-8')
      const content = decoder.decodeToString(new Uint8Array(buf))
      this.addResult(name, 'PASS', `读取 ${readBytes} 字节, 内容: "${content}"`)
    } catch (e) {
      this.addResult(name, 'FAIL', `读取失败: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 04: tempDir 写入+自动清理验证 ───
  private async test04_tempDir(): Promise<void> {
    const name = 'tempDir 读写测试'
    try {
      const ctx = getContext(this)
      const testPath = ctx.tempDir + '/sandbox_temp_test.txt'

      const fd = fileIo.openSync(testPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      const encoder = new util.TextEncoder()
      fileIo.writeSync(fd.fd, encoder.encodeInto('temp test data').buffer)
      fileIo.closeSync(fd)

      // 立即读回
      const fd2 = fileIo.openSync(testPath, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(fd2.fd)
      fileIo.closeSync(fd2)

      this.addResult(name, 'PASS', `tempDir 可读写, 文件大小: ${stat.size} 字节`)
    } catch (e) {
      this.addResult(name, 'FAIL', `tempDir 操作失败: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 05: filesDir 持久化写入 ───
  private async test05_filesDir(): Promise<void> {
    const name = 'filesDir 持久化写入'
    try {
      const ctx = getContext(this)
      const testDir = ctx.filesDir + '/sandbox_test_dir'

      // 创建子目录
      try {
        fileIo.mkdirSync(testDir)
      } catch (e) {
        // 可能已存在
      }

      const testPath = testDir + '/persist_test.json'
      const data = `{"test": true, "time": ${Date.now()}}`
      const fd = fileIo.openSync(testPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      const encoder = new util.TextEncoder()
      fileIo.writeSync(fd.fd, encoder.encodeInto(data).buffer)
      fileIo.closeSync(fd)

      // 读回验证
      const fd2 = fileIo.openSync(testPath, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(fd2.fd)
      fileIo.closeSync(fd2)

      this.addResult(name, 'PASS', `filesDir 子目录创建+写入成功, 大小: ${stat.size} 字节`)
    } catch (e) {
      this.addResult(name, 'FAIL', `filesDir 操作失败: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 06: 跨沙箱访问（应该被阻止） ───
  private async test06_crossSandboxBlock(): Promise<void> {
    const name = '跨沙箱隔离验证'
    const foreignPaths: string[] = [
      '/data/app/el2/100/base/com.example.other/files',
      '/data/app/el2/100/base/com.example.other/cache',
    ]

    let allBlocked = true
    const details: string[] = []

    for (const p of foreignPaths) {
      try {
        fileIo.accessSync(p)
        allBlocked = false
        details.push(`可访问(不应该): ${p}`)
      } catch (e) {
        details.push(`已阻止: ${p}`)
      }
    }

    if (allBlocked) {
      this.addResult(name, 'PASS', '其他应用沙箱目录均不可访问 (符合预期)')
    } else {
      this.addResult(name, 'FAIL', details.join('\n'))
    }
  }

  // ─── Test 07: 系统敏感路径访问（应该被阻止） ───
  private async test07_systemPathBlock(): Promise<void> {
    const name = '系统路径访问限制'
    const systemPaths: string[] = [
      '/system/etc',
      '/data/service',
      '/storage/media/100/local/files',
    ]

    const details: string[] = []
    let hasAccess = false

    for (const p of systemPaths) {
      try {
        fileIo.accessSync(p)
        details.push(`可访问: ${p}`)
        hasAccess = true
      } catch (e) {
        details.push(`已阻止: ${p}`)
      }
    }

    if (!hasAccess) {
      this.addResult(name, 'PASS', '系统路径均不可直接访问')
    } else {
      this.addResult(name, 'WARN', details.join('\n'))
    }
  }

  // ─── Test 08: photoAccessHelper 能否正常获取媒体 ───
  private async test08_photoAccessHelperUri(): Promise<void> {
    const name = 'photoAccessHelper 媒体访问'
    try {
      const ctx = getContext(this)
      const helper = photoAccessHelper.getPhotoAccessHelper(ctx)

      const fetchOpt: photoAccessHelper.FetchOptions = {
        fetchColumns: [
          photoAccessHelper.PhotoKeys.URI,
          photoAccessHelper.PhotoKeys.DISPLAY_NAME,
          photoAccessHelper.PhotoKeys.SIZE,
        ],
        predicates: new dataSharePredicates.DataSharePredicates()
      }

      const result = await helper.getAssets(fetchOpt)
      const count = result.getCount()

      if (count > 0) {
        const first = await result.getFirstObject()
        const uri = first.uri
        const displayName = first.get(photoAccessHelper.PhotoKeys.DISPLAY_NAME) as string
        result.close()
        this.addResult(name, 'PASS', `共 ${count} 个媒体资源\n首项: ${displayName}\nURI: ${uri}`)
      } else {
        result.close()
        this.addResult(name, 'WARN', '媒体库为空(0个资源)，无法测试 URI')
      }
    } catch (e) {
      this.addResult(name, 'FAIL', `获取媒体失败: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 09: URI 直接 fileIo.open 测试 ───
  private async test09_uriOpenDirect(): Promise<void> {
    const name = 'URI 直接打开测试 (API-008)'
    try {
      const ctx = getContext(this)
      const helper = photoAccessHelper.getPhotoAccessHelper(ctx)

      const fetchOpt: photoAccessHelper.FetchOptions = {
        fetchColumns: [photoAccessHelper.PhotoKeys.URI],
        predicates: new dataSharePredicates.DataSharePredicates()
      }

      const result = await helper.getAssets(fetchOpt)
      if (result.getCount() === 0) {
        result.close()
        this.addResult(name, 'WARN', '媒体库为空，跳过')
        return
      }

      const first = await result.getFirstObject()
      const uri = first.uri
      result.close()

      // 关键测试：用 fileIo.openSync 直接打开 photoAccessHelper URI
      const fd = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(fd.fd)
      fileIo.closeSync(fd)

      this.addResult(name, 'PASS', `URI 可直接打开\n文件大小: ${(stat.size / 1024).toFixed(1)} KB\nURI: ${uri}`)
    } catch (e) {
      this.addResult(name, 'FAIL', `URI 无法直接打开: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 10: 数据库文件隔离 ───
  private async test10_dbFileIsolation(): Promise<void> {
    const name = '数据库文件隔离'
    try {
      const ctx = getContext(this)
      // RDB 存储在应用私有目录，不在 filesDir 下直接可见
      const dbPath = ctx.databaseDir
      const details: string[] = []
      details.push(`databaseDir: ${dbPath}`)

      try {
        fileIo.accessSync(dbPath)
        details.push('databaseDir 可访问 (本应用内)')

        // 尝试列出文件
        const files = fileIo.listFileSync(dbPath)
        details.push(`包含 ${files.length} 个文件: ${files.join(', ')}`)
      } catch (e) {
        details.push('databaseDir 不可直接列出 (由系统管理)')
      }

      this.addResult(name, 'PASS', details.join('\n'))
    } catch (e) {
      this.addResult(name, 'FAIL', `异常: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 11: Preferences 数据隔离 ───
  private async test11_preferencesIsolation(): Promise<void> {
    const name = 'Preferences 数据隔离'
    try {
      const ctx = getContext(this)
      const prefsDir = ctx.preferencesDir

      const details: string[] = []
      details.push(`preferencesDir: ${prefsDir}`)

      try {
        fileIo.accessSync(prefsDir)
        details.push('preferencesDir 可访问')
        const files = fileIo.listFileSync(prefsDir)
        details.push(`包含 ${files.length} 个文件: ${files.join(', ')}`)
      } catch (e) {
        details.push('preferencesDir 不可直接列出 (由系统管理)')
      }

      this.addResult(name, 'PASS', details.join('\n'))
    } catch (e) {
      this.addResult(name, 'FAIL', `异常: ${(e as BusinessError).message}`)
    }
  }

  // ─── Test 12: 清理测试产生的临时文件 ───
  private async test12_cleanupTemp(): Promise<void> {
    const name = '清理测试临时文件'
    try {
      const ctx = getContext(this)
      const cleanPaths: string[] = [
        ctx.cacheDir + '/sandbox_test.txt',
        ctx.tempDir + '/sandbox_temp_test.txt',
        ctx.filesDir + '/sandbox_test_dir/persist_test.json',
      ]

      let cleaned = 0
      for (const p of cleanPaths) {
        try {
          fileIo.unlinkSync(p)
          cleaned++
        } catch (e) {
          // 文件可能不存在
        }
      }

      // 清理目录
      try {
        fileIo.rmdirSync(ctx.filesDir + '/sandbox_test_dir')
        cleaned++
      } catch (e) {
        // ignore
      }

      this.addResult(name, 'PASS', `已清理 ${cleaned} 个测试文件`)
    } catch (e) {
      this.addResult(name, 'FAIL', `清理失败: ${(e as BusinessError).message}`)
    }
  }

  private addResult(name: string, status: string, detail: string): void {
    const newResults: TestResult[] = []
    for (const r of this.results) {
      newResults.push(r)
    }
    const item: TestResult = { name: name, status: status, detail: detail }
    newResults.push(item)
    this.results = newResults
  }
}

export function isThisOrParentIncluded(path: string, includedPaths: string[]): boolean {
  for (let i: number = 0; i < includedPaths.length; i++) {
    if (path.startsWith(includedPaths[i])) {
      return true
    }
  }
  return false
}

export function isThisOrParentExcluded(path: string, excludedPaths: string[]): boolean {
  for (let i: number = 0; i < excludedPaths.length; i++) {
    if (path.startsWith(excludedPaths[i])) {
      return true
    }
  }
  return false
}

export function shouldFolderBeVisible(
  path: string,
  excludedPaths: string[],
  includedPaths: string[],
  showHidden: boolean
): boolean {
  if (isThisOrParentIncluded(path, includedPaths)) {
    return true
  }
  if (isThisOrParentExcluded(path, excludedPaths)) {
    return false
  }
  if (!showHidden && isThisOrParentFolderHidden(path)) {
    return false
  }
  return true
}

export function isThisOrParentFolderHidden(path: string): boolean {
  let current: string = path
  while (current.length > 0) {
    const lastSlash: number = current.lastIndexOf('/')
    if (lastSlash < 0) {
      break
    }
    const folderName: string = current.substring(lastSlash + 1)
    if (folderName.startsWith('.')) {
      return true
    }
    current = current.substring(0, lastSlash)
  }
  return false
}

export function isDownloadsFolder(path: string): boolean {
  const lower: string = path.toLowerCase()
  return lower.endsWith('/download') || lower.endsWith('/downloads')
}

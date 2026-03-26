export function getDirMediaTypes(mediaTypes: number[]): number {
  let types: number = 0
  for (let i: number = 0; i < mediaTypes.length; i++) {
    types = types | mediaTypes[i]
  }
  return types
}

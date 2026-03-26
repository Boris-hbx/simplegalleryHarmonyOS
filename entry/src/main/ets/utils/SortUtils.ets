import { SORT_DESCENDING } from '../common/constants/Constants'

export function isSortingAscending(sorting: number): boolean {
  return (sorting & SORT_DESCENDING) === 0
}

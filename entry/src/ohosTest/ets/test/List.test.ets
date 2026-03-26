import abilityTest from './Ability.test';
import MediumModelTest from './MediumModelTest';
import SortUtilsTest from './SortUtilsTest';
import PathUtilsTest from './PathUtilsTest';
import DateGroupUtilsTest from './DateGroupUtilsTest';
import ConstantsTest from './ConstantsTest';
import MediumDaoTest from './MediumDaoTest';
import MediaScannerIntegrationTest from './integration/MediaScannerIntegrationTest';
import FileOperationsIntegrationTest from './integration/FileOperationsIntegrationTest';
import ConfigManagerIntegrationTest from './integration/ConfigManagerIntegrationTest';
import MediaGrouperIntegrationTest from './integration/MediaGrouperIntegrationTest';
import CacheManagerIntegrationTest from './integration/CacheManagerIntegrationTest';

export default function testsuite() {
  abilityTest();
  MediumModelTest();
  SortUtilsTest();
  PathUtilsTest();
  DateGroupUtilsTest();
  ConstantsTest();
  MediumDaoTest();
  MediaScannerIntegrationTest();
  FileOperationsIntegrationTest();
  ConfigManagerIntegrationTest();
  MediaGrouperIntegrationTest();
  CacheManagerIntegrationTest();
}

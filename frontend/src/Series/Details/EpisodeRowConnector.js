import { connect } from 'react-redux';
import { createSelector } from 'reselect';
import createEpisodeFileSelector from 'Store/Selectors/createEpisodeFileSelector';
import createSeriesSelector from 'Store/Selectors/createSeriesSelector';
import EpisodeRow from './EpisodeRow';

function createMapStateToProps() {
  return createSelector(
    createSeriesSelector(),
    createEpisodeFileSelector(),
    (state) => state.settings.qualityProfiles.items,
    (series = {}, episodeFile, qualityProfiles) => {
      const customFormats = episodeFile ? episodeFile.customFormats : [];

      // Fork: formats flagged "Always Show" in the series' quality profile are
      // rendered as tags next to the episode title when the file matches them.
      const qualityProfile = qualityProfiles.find((profile) => profile.id === series.qualityProfileId);
      const alwaysShowFormatIds = qualityProfile ?
        qualityProfile.formatItems.filter((item) => item.alwaysShow).map((item) => item.format) :
        [];

      return {
        useSceneNumbering: series.useSceneNumbering,
        seriesMonitored: series.monitored,
        seriesType: series.seriesType,
        episodeFilePath: episodeFile ? episodeFile.path : null,
        episodeFileRelativePath: episodeFile ? episodeFile.relativePath : null,
        episodeFileSize: episodeFile ? episodeFile.size : null,
        releaseGroup: episodeFile ? episodeFile.releaseGroup : null,
        customFormats,
        alwaysShowFormats: customFormats.filter((format) => alwaysShowFormatIds.includes(format.id)),
        customFormatScore: episodeFile ? episodeFile.customFormatScore : 0,
        indexerFlags: episodeFile ? episodeFile.indexerFlags : 0,
        alternateTitles: series.alternateTitles
      };
    }
  );
}
export default connect(createMapStateToProps)(EpisodeRow);

import PropTypes from 'prop-types';
import React, { Component } from 'react';
import CheckInput from 'Components/Form/CheckInput';
import NumberInput from 'Components/Form/NumberInput';
import styles from './QualityProfileFormatItem.css';

class QualityProfileFormatItem extends Component {

  //
  // Listeners

  onScoreChange = ({ value }) => {
    const {
      formatId
    } = this.props;

    this.props.onScoreChange(formatId, value);
  };

  onAlwaysShowChange = ({ value }) => {
    const {
      formatId
    } = this.props;

    this.props.onAlwaysShowChange(formatId, value);
  };

  //
  // Render

  render() {
    const {
      name,
      score,
      alwaysShow
    } = this.props;

    return (
      <div
        className={styles.qualityProfileFormatItemContainer}
      >
        <div
          className={styles.qualityProfileFormatItem}
        >
          <label
            className={styles.formatNameContainer}
          >
            <div className={styles.formatName}>
              {name}
            </div>
            <NumberInput
              containerClassName={styles.scoreContainer}
              className={styles.scoreInput}
              name={name}
              value={score}
              onChange={this.onScoreChange}
            />
          </label>

          <CheckInput
            containerClassName={styles.alwaysShowContainer}
            className={styles.alwaysShowInput}
            name={`${name}AlwaysShow`}
            value={alwaysShow}
            onChange={this.onAlwaysShowChange}
          />
        </div>
      </div>
    );
  }
}

QualityProfileFormatItem.propTypes = {
  formatId: PropTypes.number.isRequired,
  name: PropTypes.string.isRequired,
  score: PropTypes.number.isRequired,
  alwaysShow: PropTypes.bool,
  onScoreChange: PropTypes.func,
  onAlwaysShowChange: PropTypes.func
};

QualityProfileFormatItem.defaultProps = {
  // To handle the case score is deleted during edit
  score: 0,
  alwaysShow: false
};

export default QualityProfileFormatItem;

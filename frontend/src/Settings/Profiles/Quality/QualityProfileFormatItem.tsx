import React, { useCallback } from 'react';
import CheckInput from 'Components/Form/CheckInput';
import NumberInput from 'Components/Form/NumberInput';
import { InputChanged } from 'typings/inputs';
import translate from 'Utilities/String/translate';
import styles from './QualityProfileFormatItem.module.css';

interface QualityProfileFormatItemProps {
  formatId: number;
  name: string;
  score?: number;
  alwaysShow?: boolean;
  onScoreChange: (formatId: number, score: number) => void;
  onAlwaysShowChange: (formatId: number, alwaysShow: boolean) => void;
}

function QualityProfileFormatItem({
  formatId,
  name,
  score = 0,
  alwaysShow = false,
  onScoreChange,
  onAlwaysShowChange,
}: QualityProfileFormatItemProps) {
  const handleScoreChange = useCallback(
    ({ value }: InputChanged<number>) => {
      onScoreChange(formatId, value);
    },
    [formatId, onScoreChange]
  );

  const handleAlwaysShowChange = useCallback(
    ({ value }: InputChanged<boolean>) => {
      onAlwaysShowChange(formatId, value);
    },
    [formatId, onAlwaysShowChange]
  );

  return (
    <div className={styles.qualityProfileFormatItemContainer}>
      <div className={styles.qualityProfileFormatItem}>
        <label className={styles.formatNameContainer}>
          <div className={styles.formatName}>{name}</div>
          <NumberInput
            containerClassName={styles.scoreContainer}
            className={styles.scoreInput}
            name={name}
            value={score}
            // @ts-expect-error - mismatched types
            onChange={handleScoreChange}
          />
        </label>

        {/* Fork: Always Show toggle, outside the label on purpose */}
        <CheckInput
          containerClassName={styles.alwaysShowContainer}
          className={styles.alwaysShowInput}
          name={`${name}AlwaysShow`}
          ariaLabel={translate('CustomFormatAlwaysShow')}
          value={alwaysShow}
          onChange={handleAlwaysShowChange}
        />
      </div>
    </div>
  );
}

export default QualityProfileFormatItem;

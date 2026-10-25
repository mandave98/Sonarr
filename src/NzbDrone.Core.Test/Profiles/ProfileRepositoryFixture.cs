using System.Collections.Generic;
using System.Linq;
using FluentAssertions;
using NUnit.Framework;
using NzbDrone.Core.CustomFormats;
using NzbDrone.Core.Profiles;
using NzbDrone.Core.Profiles.Qualities;
using NzbDrone.Core.Qualities;
using NzbDrone.Core.Test.Framework;

namespace NzbDrone.Core.Test.Profiles
{
    [TestFixture]
    public class ProfileRepositoryFixture : DbTest<QualityProfileRepository, QualityProfile>
    {
        [Test]
        public void should_be_able_to_read_and_write()
        {
            var profile = new QualityProfile
                {
                    Items = Qualities.QualityFixture.GetDefaultQualities(Quality.Bluray1080p, Quality.DVD, Quality.HDTV720p),
                    Cutoff = Quality.Bluray1080p.Id,
                    Name = "TestProfile"
                };

            Subject.Insert(profile);

            StoredModel.Name.Should().Be(profile.Name);
            StoredModel.Cutoff.Should().Be(profile.Cutoff);

            StoredModel.Items.Should().Equal(profile.Items, (a, b) => a.Quality == b.Quality && a.Allowed == b.Allowed);
        }

        // Fork: AlwaysShow rides along in the FormatItems JSON column
        [Test]
        public void should_persist_always_show_on_format_items()
        {
            var dualAudio = new CustomFormat { Id = 1, Name = "Dual Audio" };
            var english = new CustomFormat { Id = 2, Name = "English" };

            Mocker.GetMock<ICustomFormatService>()
                  .Setup(s => s.All())
                  .Returns(new List<CustomFormat> { dualAudio, english });

            var profile = new QualityProfile
                {
                    Items = Qualities.QualityFixture.GetDefaultQualities(Quality.Bluray1080p, Quality.DVD, Quality.HDTV720p),
                    Cutoff = Quality.Bluray1080p.Id,
                    Name = "TestProfile",
                    FormatItems = new List<ProfileFormatItem>
                    {
                        new ProfileFormatItem { Format = dualAudio, Score = 10, AlwaysShow = true },
                        new ProfileFormatItem { Format = english, Score = 0 }
                    }
                };

            Subject.Insert(profile);

            var stored = Subject.Get(profile.Id);

            stored.FormatItems.Should().HaveCount(2);
            stored.FormatItems.Single(f => f.Format.Id == dualAudio.Id).AlwaysShow.Should().BeTrue();
            stored.FormatItems.Single(f => f.Format.Id == english.Id).AlwaysShow.Should().BeFalse();
        }
    }
}

using System.Collections.Generic;
using System.Linq;
using FluentAssertions;
using NUnit.Framework;
using NzbDrone.Common.Serializer;
using NzbDrone.Core.CustomFormats;
using NzbDrone.Core.Profiles;
using NzbDrone.Core.Profiles.Qualities;
using Sonarr.Api.V3.Profiles.Quality;

namespace NzbDrone.Api.Test.v3.Profiles
{
    // Fork: covers the AlwaysShow flag on quality profile format items
    [TestFixture]
    public class QualityProfileResourceFixture
    {
        [Test]
        public void should_round_trip_always_show_through_resource()
        {
            var model = new QualityProfile
            {
                Name = "Test",
                Items = new List<QualityProfileQualityItem>(),
                FormatItems = new List<ProfileFormatItem>
                {
                    new ProfileFormatItem { Format = new CustomFormat { Id = 1, Name = "Dual Audio" }, Score = 10, AlwaysShow = true },
                    new ProfileFormatItem { Format = new CustomFormat { Id = 2, Name = "English" }, Score = 0 }
                }
            };

            var resource = model.ToResource();

            resource.FormatItems.Single(i => i.Format == 1).AlwaysShow.Should().BeTrue();
            resource.FormatItems.Single(i => i.Format == 2).AlwaysShow.Should().BeFalse();

            var roundTripped = resource.ToModel();

            roundTripped.FormatItems.Single(i => i.Format.Id == 1).AlwaysShow.Should().BeTrue();
            roundTripped.FormatItems.Single(i => i.Format.Id == 2).AlwaysShow.Should().BeFalse();
        }

        [Test]
        public void should_treat_omitted_always_show_as_false_when_mapping_to_model()
        {
            var resource = STJson.Deserialize<QualityProfileResource>("{ \"name\": \"Test\", \"items\": [], \"formatItems\": [ { \"format\": 1, \"score\": 5 } ] }");

            resource.FormatItems.Single().AlwaysShow.Should().BeNull();
            resource.ToModel().FormatItems.Single().AlwaysShow.Should().BeFalse();
        }

        [Test]
        public void should_preserve_stored_always_show_only_for_items_that_omitted_it()
        {
            var resource = STJson.Deserialize<QualityProfileResource>("{ \"id\": 1, \"name\": \"Test\", \"items\": [], \"formatItems\": [ { \"format\": 1, \"score\": 5 }, { \"format\": 2, \"score\": 0, \"alwaysShow\": false }, { \"format\": 3, \"score\": 0 } ] }");
            var model = resource.ToModel();

            var stored = new QualityProfile
            {
                Id = 1,
                FormatItems = new List<ProfileFormatItem>
                {
                    new ProfileFormatItem { Format = new CustomFormat { Id = 1 }, AlwaysShow = true },
                    new ProfileFormatItem { Format = new CustomFormat { Id = 2 }, AlwaysShow = true }
                }
            };

            model.PreserveOmittedAlwaysShow(resource, stored);

            // omitted by the client, so the stored flag survives
            model.FormatItems.Single(i => i.Format.Id == 1).AlwaysShow.Should().BeTrue();

            // explicitly sent as false, so the client wins
            model.FormatItems.Single(i => i.Format.Id == 2).AlwaysShow.Should().BeFalse();

            // omitted and unknown to the stored profile, so it stays at the default
            model.FormatItems.Single(i => i.Format.Id == 3).AlwaysShow.Should().BeFalse();
        }
    }
}

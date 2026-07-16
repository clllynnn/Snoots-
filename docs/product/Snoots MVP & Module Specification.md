# Snoots! MVP & Module Specification

## Product Role

During development, Maps is Snoots!’s entry point rather than a directory. Its job is to help an owner make a quick, low-anxiety decision:

> Is this place actually suitable for my dog today?

## 1. Explore Nearby Places

The default screen opens to a map centered on the owner’s current area, with a bottom sheet of nearby places. A person should be able to scan pins, tap one, and understand the key restriction without opening every detail page.

Each pin or list card shows:

- Venue name and category
- Distance and open or closed status
- One clear pet-access label: `Indoor OK`, `Outdoor only`, `Carrier required`, or `Restrictions apply`
- Verification state and last-confirmed date

“Pet-friendly” is never the main label. Snoots! should state what the owner can actually do.

## 2. Search and Filtering

Search supports venue names, areas, and intent—not only keywords. Example searches include “indoor café,” “large dog,” or “rainy-day place.”

MVP filters:

- Venue category
- Open now
- Indoor access
- Dog size accepted
- Stroller or carrier required
- Verified details only
- Distance

Later filters may include pet menus, parking, water bowls, shade, and accessibility. They should not crowd the first decision.

## 3. Venue Policy Card

Every venue has a standardized **Dog access** card rather than free-form descriptions.

The card answers, in this order:

1. Can the dog enter indoors?
2. Is there a size or weight limit?
3. Must the dog use a leash, stroller, carrier, muzzle, or courtesy belt?
4. Are there seating or floor rules?
5. Are there time or day restrictions?
6. When and by whom was this confirmed?

Example:

> Indoor access allowed. Dogs must remain on the floor and be leashed. Large dogs accepted. Policy confirmed by venue on 12 Jul 2026.

This is more useful than a general review that says the staff love dogs.

## 4. Practical Venue Information

Below the access policy, the venue detail page supports the real visit:

- Opening hours and current open status
- Address, call, navigation, website, and social link
- Facilities: water bowl, waste bin, shade, outdoor seating, and parking
- Recent community photos
- Brief real-world notes, such as “tight indoor aisles” or “busy after 2 pm”

The primary action remains **Navigate**. The page should not become a social feed before it proves the venue information is accurate.

## 5. Verification and Updates

Every piece of venue data needs a source and date.

Verification levels:

- **Venue confirmed** — the business supplied or explicitly confirmed the policy.
- **Community confirmed** — a recent visitor reports that the listed policy was correct.
- **Needs reconfirmation** — information is old or conflicting.

After navigating to or saving a place, Snoots! can ask a lightweight question:

> Was the dog-access information correct?

The owner can:

- Confirm the policy
- Report a changed rule
- Add a missing condition
- Mark the venue closed

This maintains the product’s most valuable data more directly than general reviews.

## 6. Save and Return

Saved places are the main retention function for the Maps MVP.

Initial default lists:

- Want to visit
- Favorites
- Rainy-day options
- Safe for small dog

Users can later create their own lists, such as “Da’an weekend walk,” “Dog-friendly date night,” or “Large-dog cafés.” Sharing a list can become an early social action without requiring a full Social Feed.

## 7. Dog Profile as a Personalization Layer

The owner adds only information that makes Maps more useful:

- Dog name and photo
- Size or approximate weight
- Relevant access needs
- Optional temperament note

Snoots! can then flag poor fits:

> Carrier required — may not suit Mochi

> Large dogs not accepted

> Good match for a 12 kg dog

Personalization should assist rather than silently hide results. An owner may still want to see a carrier-required café even if they do not normally use one.

## 8. Maps MVP Development Boundaries

Do not build these during the Maps MVP development phase:

- Public star ratings
- Long-form venue reviews
- Owner-to-owner messaging
- Playdate matching
- Full social feed, posting, and interactions
- Live capacity or real-time availability claims

These create moderation or operational complexity before Snoots! has a reliable venue-policy database. They are deferred during development; the full social network is part of the product-launch vision.

## Maps MVP Product Loop

```text
Discover → check policy → visit → confirm policy → save or revisit
```

## MVP Venue Scope

During development, Maps covers only dog-friendly cafés, restaurants, and parks. This is the easiest user entry point and keeps venue policies consistent while the product is being validated.

---

# Four-Module Product Model

Maps is the early entry point. After launch, Snoots! is a general-purpose social network for dogs—similar to how Instagram connects people—with Maps, Playdate Matching, and Emergency Guidance as connected utilities.

| Module | Core job | Primary user action | Key output |
| --- | --- | --- | --- |
| Maps | Decide where to go with a dog | Search a café, restaurant, or park | A confident visit decision |
| Social Feed | Share a dog’s life and connect with the dog-owner community | Post, follow, and interact | An active dog-focused social network |
| Playdate Matching | Find compatible dogs and plan a one-to-one or group meetup | Join or create a playdate | A confirmed playdate |
| Emergency Guidance | Reach appropriate care and support without delay | Call, navigate, and share a condition update | Fast clinical and personal support |

## 9. Maps: The MVP Entry Point

Maps is the first feature built during development. It establishes Snoots! as useful from the first visit and introduces people to the wider dog community.

### Maps functions used by other modules

- Provide a verified venue when an owner wants to recommend a place in a post.
- Suggest suitable meeting venues during playdate planning.
- Keep policy changes, closures, and verification dates consistent everywhere.

### MVP venue scope

Only cafés, restaurants, and parks are in scope during the MVP. They support the most frequent “Can I bring my dog?” decisions and give future playdates suitable meeting places.

## 10. Social Feed: The Core Dog Community

After launch, Social Feed is Snoots!’s main social experience: an Instagram-like network where dogs have identities, owners share their dogs’ lives, and people build a dog-owner community.

### Core functions

- Create a dog profile with a name, photo, bio, breed, age, and owner-managed privacy settings.
- Create photo, video, and text posts about daily life, milestones, playdates, walks, or questions for the community.
- Follow dogs and owners; show a home feed from followed accounts and an Explore feed for new dog content.
- Like, comment on, save, and share posts.
- Tag dogs, people, and an optional venue in a post.
- Add photos and short visit notes to a venue without changing the official policy record.
- Report misinformation, unsafe content, or harassment; mute or block owners when needed.

### Trust rules

- A post can say “we visited with a small dog,” but it cannot overwrite a venue’s access policy.
- Posts linked to a venue show the visit date and the venue’s current verification state.
- A venue-policy correction routes into the structured Maps update flow, not into comments.

### Early-development constraints

During the Maps MVP, Snoots! does not need to build the full feed, sophisticated ranking, creator tools, or commercial promotion. These are deferred only while the initial map experience is developed—not limits on the launched social product.

The desired loop is:

```text
Share a dog’s life → connect with other owners → discover places and playmates → return to share again
```

## 11. Playdate Matching: Safety Before Conversation

Playdate Matching makes real-world meetings safer and easier to arrange, whether an owner wants a one-to-one playmate or a small group of compatible dogs.

### Dog and owner profile functions

- Dog basics: age, size, sex, neutering status, and activity level.
- Play preferences: gentle, chase, wrestling, parallel walking, group play, or one-to-one play.
- Comfort boundaries: preferred dog size, puppy tolerance, senior-dog suitability, and whether a slow introduction is needed.
- Owner availability: preferred days, times, travel distance, and group size.
- Safety disclosures: vaccination status and behavior expectations, with an optional verification path.

### Matching functions

- Filter candidates by distance, dog size, energy level, play style, and availability.
- Present an understandable compatibility summary, such as “similar energy, both prefer gentle play, and have overlapping Sunday mornings.”
- Let an owner pass, save, or express interest in an individual dog or an open group playdate.
- Create a private chat after a mutual one-to-one match; let a group host approve members before they join a group chat.
- Allow either owner to unmatch, block, or report at any time.

### Meetup-planning functions

- Create either a one-to-one playdate or a group playdate with a maximum number of dogs.
- Propose times and choose a venue from Maps.
- Use venue data to check whether the location suits the participating dogs, including size and access restrictions.
- Confirm attendance, first-meeting expectations, and equipment such as leashes.
- Send a simple reminder before the meetup.
- Collect private post-meetup feedback: meet again, venue worked well, or report a safety issue.

### MVP boundary for this module

Do not launch matching until Snoots! can support clear dog profiles, reporting/blocking, and a meaningful set of suitable map venues. A fast swipe interaction is not the product’s value; safe coordination is.

## 12. Emergency Guidance: Fast Care Navigation

Emergency Guidance is a high-trust utility, not a content module. Its interface must minimize reading, decisions, and typing under stress.

### Emergency-entry functions

- Offer a persistent emergency action from Maps and other major screens.
- Use the owner’s location to show nearby clinics that are currently open.
- Prioritize travel time, then clinical capability—not popularity.
- Clearly label the freshness and source of operating-hours information.

### Clinic-result functions

- Show distance, estimated travel time, open status, phone number, and address.
- Identify capabilities such as 24-hour care, surgery, trauma care, imaging, oxygen, and hospitalization.
- Provide one-tap **Call** and **Navigate** actions.
- Allow an owner to share their location and selected clinic with a trusted contact.

### Dog medical-card functions

- Keep the owner’s emergency contact, dog weight, allergies, medications, and relevant conditions in one concise card.
- Make the card easy to show at clinic arrival or share with a caregiver.
- Keep it separate from social profile information and visible only to the owner unless they intentionally share it.

### Condition description and emotional support

- Let the owner add a photo, voice recording, or short text description of the dog’s current condition.
- Keep this update private by default; allow the owner to share it with a selected clinic, caregiver, or trusted contact.
- Provide calm, compassionate support while the owner takes action, such as confirming that help is being contacted and offering a one-tap way to notify a trusted person.
- Allow the owner to share their live location and the selected clinic with that person.

### Safety boundary

Snoots! can help an owner find appropriate care and prepare information, but it should not diagnose a dog or advise delaying urgent veterinary care. Any symptom prompts should direct the owner to call a clinic or seek emergency help.

## 13. Cross-Module Journeys

The modules should connect through small, purposeful handoffs:

```text
Maps → Save a suitable café → Share a recent visit in Social Feed
Maps → Find a suitable park → Use it to plan a Playdate
Emergency Guidance → Find an open clinic → Navigate and present the dog medical card
```

No module needs to force users through another. An owner can use Maps every day without posting, matching, or sharing medical information.

## 14. Recommended Release Sequence

1. **Maps MVP during development** — cafés, restaurants, and parks; policy cards, navigation, saves, and structured updates.
2. **Social launch** — dog profiles, photo/video/text posts, follows, feed, and interactions as the core Snoots! experience.
3. **Safe coordination** — one-to-one and group matching, chat, and map-backed meetup planning.
4. **High-trust utility** — emergency clinic finder, dog medical card, condition sharing, and emotional support.

This order gives Snoots! an easy Maps entry point during development, then launches the broader dog social network with additional real-world and high-trust utilities.

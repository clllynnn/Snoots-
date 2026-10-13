import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class SnootsStore {
    var profile = ParentProfile(name: "小安", petName: "豆花", trustScore: 92, neighborhood: "Da’an District, Taipei")
    var pet = PetProfile(
        name: "豆花",
        imageName: "Tofu",
        breed: "博美",
        age: "3 歲",
        size: "小型犬",
        sex: "公",
        isNeutered: true,
        socialStyle: "先觀察再靠近",
        summary: "豆花習慣先觀察，熟悉後會自在地一起散步。",
        traits: ["慢慢認識", "先牽繩互動"],
        healthStatus: "Vaccinations and behavior card verified"
    )
    var hasCompletedOnboarding = false
    var matchDetailsCompleted = false
    var safetyDetailsCompleted = false
    let feedingMonitor = FeedingMonitor(
        isOnline: true,
        lastFedHoursAgo: 3,
        waterIntakeMilliliters: 200,
        waterGoalMilliliters: 1200
    )
    let care = PetCareProfile(
        rabies: VaccineRecord(
            vaccinatedOn: "14 Sep 2025",
            validUntil: "14 Sep 2026",
            clinic: "Da’an Animal Hospital",
            manufacturer: "Nobivac Rabies",
            batchNumber: "RAB-250914"
        ),
        otherVaccinationsCount: 2,
            healthNotes: "Neutered 8 Mar 2025 · No chronic conditions\nLast vet visit 10 Jul 2026"
    )
    var isMatched = false
    var hasMatchChat = false
    var matchChatMessages: [MatchChatMessage] = []
    var meetupGroupMessages: [MeetupGroupMessage] = [
        MeetupGroupMessage(senderName: "豆花", text: "大家好！別忘了先上傳狗狗打招呼照片，讓見面更安心。", isOutgoing: true),
        MeetupGroupMessage(senderName: "超超", text: "收到，我已經完成守則確認，期待一起散步！", isOutgoing: false)
    ]
    var meetupGroupAnnouncement = "這是一場輕鬆的平行散步，適合正在建立自信、學習與其他狗狗相處的毛孩。"
    var meetupGroupAllowsMemberMessages = true
    var meetupGroupAllowsPhotoSharing = true
    var interactionRecords: [InteractionRecord] = []
    var hasCompletedIcebreaker = false
    var completedIcebreakerTaskTitle = ""
    var dailyIcebreakerResult: DailyIcebreakerResult?
    var hasPreparedMeetupInvitation = false
    var hasSeenMeetupInvitationPrompt = false
    var isMatchCancelled = false
    var isMatchBlocked = false
    var reportedMatchReasons: [MatchReportReason] = []
    var hasSentMeetupInvite = false
    var hasAcknowledgedBoundaries = false
    var hasCompletedSafetyCheckIn = false
    var sparkPoints = 0
    var wantsNextMeetup = false
    var hasMutualNextMeetup = false
    var hasSentWarmFeedback = false
    var lastWarmFeedbackTags: [String] = []
    var lastWarmFeedbackNote = ""
    var lastWarmFeedbackHasPhoto = false
    var lastWarmFeedbackRecipientName = "超超"
    var lastWarmFeedbackRecipientOwner = "David"
    var lastWarmFeedbackRecipientImageName = "ChaoChao1"
    var careStepIndex = 0
    var savedPlaceIDs: Set<String> = []
    var createdMeetups: [MeetupDraft] = []
    var completedUpcomingMeetupTaskIDs: Set<String> = []
    var hasAcknowledgedUpcomingMeetupGuidance = false
    var isUpcomingMeetupCheckInOpen = false
    var hasCompletedGroupMeetupCheckIn = false
    var hasTemporarilyLeftGroupMeetup = false
    var hasEndedGroupMeetup = false
    let mapPlaces = MapPlacesRepository()

    let meetupActivityTypes = [
        MeetupActivityType(id: "grass-play", symbol: "leaf", title: "Grass playtime", traditionalChineseTitle: "草皮放風"),
        MeetupActivityType(id: "camping", symbol: "tent", title: "Camping", traditionalChineseTitle: "露營野宿"),
        MeetupActivityType(id: "costume", symbol: "party.popper", title: "Festive dress-up", traditionalChineseTitle: "節慶變裝"),
        MeetupActivityType(id: "dining", symbol: "fork.knife", title: "Dog-friendly dining", traditionalChineseTitle: "寵物友善聚餐"),
        MeetupActivityType(id: "owner-social", symbol: "person.2", title: "Meet other dog parents", traditionalChineseTitle: "飼主交友"),
        MeetupActivityType(id: "health", symbol: "cross.case", title: "Community health checks", traditionalChineseTitle: "公益健檢")
    ]
    let meetupVenues = [
        MeetupVenue(id: "daan-forest", mapPlaceID: "daan-forest", name: "Da’an Forest Park · East Gate", traditionalChineseName: "大安森林公園 · 東門"),
        MeetupVenue(id: "riverside", mapPlaceID: "xinyi-dog-park", name: "Riverside Park · Lawn", traditionalChineseName: "河濱公園 · 草地區"),
        MeetupVenue(id: "companion", mapPlaceID: "companion", name: "Companion Cafe · Patio", traditionalChineseName: "Companion Cafe · 戶外座位")
    ]
    let meetupSafetyOptions = [
        MeetupSafetyOption(id: "Leash on", title: "Leash on", traditionalChineseTitle: "全程牽繩"),
        MeetupSafetyOption(id: "Slow introductions", title: "Slow introductions", traditionalChineseTitle: "慢慢認識"),
        MeetupSafetyOption(id: "Adult dogs", title: "Adult dogs", traditionalChineseTitle: "偏好成犬")
    ]
    var upcomingMeetup = UpcomingMeetup(
        title: "Momo Doggo Club",
        traditionalChineseTitle: "萌萌狗勾幫",
        organizerName: "Tofu",
        traditionalChineseOrganizerName: "豆花",
        startDate: Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 10, day: 31, hour: 12)
        ) ?? .now,
        durationHours: 2,
        location: "Da’an Forest Park",
        traditionalChineseLocation: "大安森林公園",
        hostNote: "A calm parallel walk for dogs learning to socialise.",
        traditionalChineseHostNote: "這是一場輕鬆的平行散步，適合正在建立自信、學習與其他狗狗相處的毛孩。",
        participants: [
            MeetupParticipant(name: "Tofu", traditionalChineseName: "豆花", imageName: "Tofu", breed: "博美", age: "3 歲", size: "小型犬", summary: "先觀察再靠近，熟悉後喜歡一起散步。", healthSummary: "狂犬病疫苗已施打・定期驅蟲", safetyTagIDs: ["slow-intro", "leash"]),
            MeetupParticipant(name: "ChaoChao", traditionalChineseName: "超超", imageName: "ChaoChao1", breed: "博美", age: "2 歲", size: "小型犬", summary: "比較害羞，喜歡以安靜散步慢慢認識新朋友。", healthSummary: "狂犬病疫苗已施打・定期驅蟲", safetyTagIDs: ["slow-intro", "adult"]),
            MeetupParticipant(name: "Mochi", traditionalChineseName: "麻糬", imageName: "Mochi", breed: "柴犬", age: "4 歲", size: "中型犬", summary: "喜歡有距離感的初次互動，熟悉後很愛玩。", healthSummary: "疫苗紀錄已分享・定期驅蟲", safetyTagIDs: ["leash"]),
            MeetupParticipant(name: "Pudding", traditionalChineseName: "布丁", imageName: "Pudding", breed: "比熊犬", age: "3 歲", size: "小型犬", summary: "個性溫和，偏好和成犬一起散步。", healthSummary: "疫苗紀錄已分享・定期驅蟲", safetyTagIDs: ["adult"]),
            MeetupParticipant(name: "Nori", traditionalChineseName: "諾里", imageName: "Nori", breed: "米克斯", age: "5 歲", size: "中型犬", summary: "步調穩定，喜歡先牽繩一起探索環境。", healthSummary: "疫苗紀錄已分享・定期驅蟲", safetyTagIDs: ["leash"])
        ],
        totalParticipantCount: 5,
        readyParticipantCount: 3,
        preparationTasks: [
            MeetupPreparationTask(id: "hello-photo", title: "Upload a hello photo", traditionalChineseTitle: "上傳狗狗打招呼照片", completedParticipantCount: 3, totalParticipantCount: 5, symbol: "photo"),
            MeetupPreparationTask(id: "rules", title: "Confirm meetup rules", traditionalChineseTitle: "確認聚會守則", completedParticipantCount: 4, totalParticipantCount: 5, symbol: "checkmark.shield"),
            MeetupPreparationTask(id: "arrival", title: "Share arrival details", traditionalChineseTitle: "確認抵達方式", completedParticipantCount: 2, totalParticipantCount: 5, symbol: "location")
        ]
    )

    var socialPosts: [SocialPost] = [
        SocialPost(
            owner: "豆花", petName: "豆花", location: "大安森林公園", timeAgo: "今天",
            body: "草地上認識了新朋友！先留一點距離、慢慢聞一聞，今天的散步多了好多可愛的回憶。",
            declarations: ["慢慢認識", "牽繩散步"], likes: 48, comments: 2, kind: .photo, photoName: "Tofu",
            title: "草地上的新朋友", month: 10, day: 8,
            galleryPhotoNames: ["MeetupHeroDogs", "Tofu", "Nori"],
            replies: [
                SocialPostComment(author: "麻糬", text: "這個打招呼的距離剛剛好，好可愛！"),
                SocialPostComment(author: "超超", text: "下次也想一起慢慢散步 🐾")
            ]
        ),
        SocialPost(
            owner: "麻糬", petName: "麻糬", location: "北海岸", timeAgo: "2 天前",
            body: "把步調放慢，陪毛孩吹吹海風。今天沒有趕行程，只有散步、看海，還有一直搖的尾巴。",
            declarations: ["海邊散步", "記得補水"], likes: 36, comments: 2, kind: .photo, photoName: "Mochi",
            title: "和毛孩一起追海風", month: 10, day: 6,
            galleryPhotoNames: ["Mochi", "TerraceTable", "Pudding"],
            replies: [
                SocialPostComment(author: "豆花", text: "海風把耳朵都吹起來了！"),
                SocialPostComment(author: "布丁", text: "這樣的散步好療癒。")
            ]
        ),
        SocialPost(
            owner: "超超", petName: "超超", location: "在家也很開心", timeAgo: "4 天前",
            body: "今天的任務是好好休息。洗香香、躺回最愛的小窩，再靠近鏡頭跟大家打個招呼。",
            declarations: ["居家日常", "放鬆一下"], likes: 62, comments: 2, kind: .photo, photoName: "ChaoChao1",
            title: "超超的放空小日子", month: 10, day: 4,
            galleryPhotoNames: ["ChaoChao1", "ChaoChao3", "ChaoChao4"],
            replies: [
                SocialPostComment(author: "諾里", text: "根本是一朵棉花糖！"),
                SocialPostComment(author: "豆花", text: "今天也有認真可愛 🤍")
            ]
        )
    ]

    func addSocialPostComment(to postID: UUID, text: String) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let index = socialPosts.firstIndex(where: { $0.id == postID }) else { return }
        socialPosts[index].replies.append(SocialPostComment(author: pet.name, text: message))
        socialPosts[index].comments += 1
    }

    let playdate = PlaydateCandidate(
        name: "超超",
        age: "2 y",
        owner: "David",
        distance: "1.2 km away",
        imageName: "ChaoChao1",
        photoNames: ["ChaoChao1", "ChaoChao2", "ChaoChao3", "ChaoChao4"],
        compatibility: ["Slow to warm up", "Leash-first", "Similar size"],
        accountability: "Identity verified · Vaccines shared",
        intro: "超超比較害羞，希望能找到一起安靜散步的小狗夥伴！",
        breed: "博美",
        size: "小型犬",
        sex: "母",
        isNeutered: false,
        strangerDogReaction: "害怕，但會嘗試接近",
        energyLevel: "中等（慢速散步型）",
        meetingEnvironments: ["開放式公園"],
        healthSummary: "狂犬病疫苗已施打・每月定期驅蟲",
        isRabiesVaccinated: true,
        hasMonthlyParasitePrevention: true
    )

    let criticalSymptoms = ["Repeated vomiting", "Very quiet", "Possible toxin"]
    let careSteps = [
        CareStep(title: "Keep the ride calm", instruction: "Use a secure carrier or harness. Keep the space quiet and avoid food or medication unless a licensed clinician tells you otherwise.", symbol: "car.fill"),
        CareStep(title: "Prepare the handoff", instruction: "Have the time symptoms started, possible exposure, and a short video ready to share when you arrive.", symbol: "doc.text.fill"),
        CareStep(title: "Arrive and repeat the facts", instruction: "At reception, state the symptoms and possible toxin exposure clearly. The clinic will take over the real assessment.", symbol: "building.2.fill")
    ]
    let clinic = Clinic(name: "Da’an Night Animal Clinic", eta: "8 min", address: "104 Fuxing S. Rd., Da’an District", handoff: "Symptom and exposure summary ready")

    let places = [
        Place(id: "companion", name: "Companion Cafe", category: "Cafe", nearbyCategory: .dining, region: .zhongzheng, walk: "4 min walk", walkMinutes: 4, imageName: "CompanionCafe", rules: [.stroller, .indoorLeash, .seatCover], verified: "today, 18:40", dogAccess: .indoorOK, verificationLevel: .venueConfirmed, lastConfirmed: "17 Jul 2026", verificationSource: "Venue confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0324, longitude: 121.5446, address: "No. 18, Lane 181, Section 3, Roosevelt Rd.", facilities: [.waterBowl, .wasteBin, .shade, .outdoorSeating], intentKeywords: "indoor cafe rainy day large dog"),
        Place(id: "terrace", name: "Terrace Table", category: "Bistro", nearbyCategory: .dining, region: .daan, walk: "7 min walk", walkMinutes: 7, imageName: "TerraceTable", rules: [.outdoorOnly, .waterBowl], verified: "14 Jul", dogAccess: .outdoorOnly, verificationLevel: .communityConfirmed, lastConfirmed: "14 Jul 2026", verificationSource: "Community confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0372, longitude: 121.5483, address: "No. 42, Yongkang St., Da’an District", facilities: [.waterBowl, .shade, .outdoorSeating], intentKeywords: "patio outdoor bistro large dog"),
        Place(id: "pages", name: "Paws & Pages", category: "Book bar", nearbyCategory: .dining, region: .daan, walk: "11 min walk", walkMinutes: 11, imageName: "Pudding", rules: [.stroller, .indoorLeash, .quietHours], verified: "12 Jul", dogAccess: .carrierRequired, verificationLevel: .needsReconfirmation, lastConfirmed: "12 Jul 2026", verificationSource: "Community report", acceptsLargeDogs: false, isOpenNow: false, latitude: 25.0296, longitude: 121.5358, address: "No. 9, Lane 243, Heping E. Rd.", facilities: [.wasteBin, .shade], intentKeywords: "book bar carrier quiet rainy day"),
        Place(id: "morning-walk", name: "Da’an Morning Social Walk", category: "Leashed group walk", nearbyCategory: .meetups, region: .daan, walk: "6 min walk", walkMinutes: 6, imageName: "Nori", rules: [.indoorLeash], verified: "today, 08:10", dogAccess: .restrictionsApply, verificationLevel: .communityConfirmed, lastConfirmed: "17 Jul 2026", verificationSource: "Host confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0311, longitude: 121.5368, address: "Da’an Forest Park, East Gate", facilities: [.waterBowl, .wasteBin, .shade], intentKeywords: "dog meetup group walk large dog leashed"),
        Place(id: "rainy-club", name: "Rainy Day Puppy Club", category: "Indoor dog meetup", nearbyCategory: .meetups, region: .xinyi, walk: "9 min walk", walkMinutes: 9, imageName: "Mochi", rules: [.indoorLeash, .quietHours], verified: "16 Jul", dogAccess: .indoorOK, verificationLevel: .venueConfirmed, lastConfirmed: "16 Jul 2026", verificationSource: "Host and venue confirmed", acceptsLargeDogs: false, isOpenNow: true, latitude: 25.0415, longitude: 121.5631, address: "No. 15, Lane 201, Guangfu S. Rd.", facilities: [.waterBowl, .parking], intentKeywords: "indoor meetup rainy day small dog"),
        Place(id: "daan-forest", name: "Da’an Forest Park", category: "Urban park", nearbyCategory: .parks, region: .daan, walk: "5 min walk", walkMinutes: 5, imageName: "Nori", rules: [.indoorLeash, .waterBowl], verified: "17 Jul", dogAccess: .outdoorOnly, verificationLevel: .communityConfirmed, lastConfirmed: "17 Jul 2026", verificationSource: "Community confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0297, longitude: 121.5358, address: "No. 1, Section 2, Xinsheng S. Rd., Da’an District", facilities: [.waterBowl, .wasteBin, .shade], intentKeywords: "park shade walk large dog"),
        Place(id: "xinyi-dog-park", name: "Xinyi Riverside Dog Park", category: "Dog park", nearbyCategory: .parks, region: .xinyi, walk: "13 min walk", walkMinutes: 13, imageName: "Mochi", rules: [.outdoorOnly, .waterBowl], verified: "16 Jul", dogAccess: .outdoorOnly, verificationLevel: .communityConfirmed, lastConfirmed: "16 Jul 2026", verificationSource: "Community confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0412, longitude: 121.5742, address: "Xinyi Riverside, Xinyi District", facilities: [.waterBowl, .wasteBin, .shade, .parking], intentKeywords: "dog park outdoor large dog free roam"),
        Place(id: "daan-night", name: "Da’an Night Animal Clinic", category: "Emergency veterinary clinic", nearbyCategory: .vets, region: .daan, walk: "8 min walk", walkMinutes: 8, imageName: "CompanionCafe", rules: [.indoorLeash], verified: "17 Jul", dogAccess: .restrictionsApply, verificationLevel: .venueConfirmed, lastConfirmed: "17 Jul 2026", verificationSource: "Clinic confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0391, longitude: 121.5438, address: "104 Fuxing S. Rd., Da’an District", facilities: [.parking, .waterBowl], intentKeywords: "emergency vet hospital large dog"),
        Place(id: "xinyi-vet", name: "Xinyi Animal Hospital", category: "Veterinary hospital", nearbyCategory: .vets, region: .xinyi, walk: "14 min walk", walkMinutes: 14, imageName: "TerraceTable", rules: [.indoorLeash], verified: "10 Jul", dogAccess: .restrictionsApply, verificationLevel: .needsReconfirmation, lastConfirmed: "10 Jul 2026", verificationSource: "Community report", acceptsLargeDogs: true, isOpenNow: false, latitude: 25.0339, longitude: 121.5611, address: "No. 98, Section 5, Xinyi Rd.", facilities: [.parking, .wasteBin], intentKeywords: "vet hospital emergency")
    ]

    var currentCareStep: CareStep { careSteps[careStepIndex] }
    var allPlaces: [Place] { createdMeetups.compactMap(meetupPlace) + places }
    var savedPlaces: [Place] { allPlaces.filter { savedPlaceIDs.contains($0.id) } }

    func advanceCareStep() {
        careStepIndex = min(careStepIndex + 1, careSteps.count - 1)
    }

    func place(id: String) -> Place? { allPlaces.first { $0.id == id } }
    func isSaved(_ place: Place) -> Bool { savedPlaceIDs.contains(place.id) }

    func toggleSaved(_ place: Place) {
        if savedPlaceIDs.contains(place.id) {
            savedPlaceIDs.remove(place.id)
        } else {
            savedPlaceIDs.insert(place.id)
        }
    }

    func updateProfile(ownerName: String, neighborhood: String, petName: String, ownerMessage: String) {
        profile.name = ownerName
        profile.neighborhood = neighborhood
        profile.petName = petName
        pet.name = petName
        profile.ownerMessage = ownerMessage
    }

    func applyRegisteredProfile(owner: RegisteredOwner, dog: RegisteredDog, photoData: Data?) {
        profile.name = owner.nickname
        profile.email = ""
        profile.petName = dog.name
        pet.name = dog.name
        pet.breed = dog.breed
        pet.breedMappingPending = dog.breedMappingStatus == "pending"
        pet.age = "尚未填寫"
        pet.size = switch dog.size {
        case "small": "小型犬"
        case "medium": "中型犬"
        default: "大型犬"
        }
        pet.sex = dog.sex == "male" ? "公" : "母"
        pet.isNeutered = dog.isNeutered
        pet.socialStyle = switch dog.socialStyle {
        case "friendly": "主動友好"
        case "observe_then_interact": "先觀察，再互動"
        case "fearful_approach": "害怕，但會嘗試靠近"
        case "fearful_avoid": "害怕並躲開"
        default: "吠叫或低吠"
        }
        pet.summary = ""
        pet.traits = []
        pet.photoData = photoData
        hasCompletedOnboarding = true
    }

    func saveMatchDetails(_ details: DogMatchingProfile) {
        pet.matchingProfile = details
        if let birthDate = details.birthDate {
            let years = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0
            let months = Calendar.current.dateComponents([.month], from: birthDate, to: .now).month ?? 0
            pet.age = years > 0 ? "\(years) 歲" : "\(months) 個月"
        }
        pet.preferredMeetingEnvironments = details.meetingEnvironments
        var protectionLabels: [(String, String?)] = [
            ("狂犬病疫苗", details.protectionAnswers["狂犬病疫苗在有效期間"]),
            ("體內外驅蟲", details.protectionAnswers["已完成體內外驅蟲"]),
            ("晶片與寵物登記", details.protectionAnswers["晶片與寵物登記"])
        ]
        if let birthDate = details.birthDate,
           (Calendar.current.dateComponents([.month], from: birthDate, to: .now).month ?? 999) < 5 {
            protectionLabels.insert(("核心疫苗", details.protectionAnswers["核心疫苗已完成"]), at: 0)
        }
        pet.vaccineSummary = protectionLabels.compactMap { label, answer in
            answer == "有" ? "\(label)：已分享" : nil
        }.joined(separator: "・")
        matchDetailsCompleted = true
    }

    func saveSafetyDetails(vaccineSummary: String, emergencyPhone: String, leashHabit: String) {
        pet.vaccineSummary = vaccineSummary
        pet.emergencyPhone = emergencyPhone
        pet.leashHabit = leashHabit
        safetyDetailsCompleted = true
    }

    func createMatchChat() {
        hasMatchChat = true
    }

    func sendMatchChatMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        matchChatMessages.append(MatchChatMessage(text: trimmedText, isOutgoing: true))
        matchChatMessages.append(
            MatchChatMessage(
                text: "謝謝你分享！超超也很期待用舒服的步調認識豆花。",
                isOutgoing: false
            )
        )
    }

    func sendMeetupGroupMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        meetupGroupMessages.append(MeetupGroupMessage(senderName: "豆花", text: trimmedText, isOutgoing: true))
    }

    func updateMeetupGroupSettings(
        announcement: String,
        allowsMemberMessages: Bool,
        allowsPhotoSharing: Bool
    ) {
        meetupGroupAnnouncement = announcement.trimmingCharacters(in: .whitespacesAndNewlines)
        meetupGroupAllowsMemberMessages = allowsMemberMessages
        meetupGroupAllowsPhotoSharing = allowsPhotoSharing
    }

    var dailyIcebreakerTask: DailyIcebreakerTask {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return DailyIcebreakerTask.all[dayOfYear % DailyIcebreakerTask.all.count]
    }

    var hasCompletedTodayIcebreaker: Bool {
        guard let dailyIcebreakerResult else { return false }
        return Calendar.current.isDateInToday(dailyIcebreakerResult.completedAt)
    }

    @discardableResult
    func completeDailyIcebreaker(answerID: String) -> DailyIcebreakerResult? {
        guard !hasCompletedTodayIcebreaker,
              let selectedAnswer = dailyIcebreakerTask.options.first(where: { $0.id == answerID }),
              let chaoChaoAnswer = dailyIcebreakerTask.options.first(where: { $0.id == dailyIcebreakerTask.chaoChaoAnswerID })
        else { return nil }

        let result = DailyIcebreakerResult(
            taskID: dailyIcebreakerTask.id,
            taskTitle: dailyIcebreakerTask.title,
            prompt: dailyIcebreakerTask.prompt,
            tofuAnswer: selectedAnswer,
            chaoChaoAnswer: chaoChaoAnswer,
            similarityPercent: selectedAnswer.similarityPercent,
            familiarityPoints: selectedAnswer.familiarityPoints,
            completedAt: .now
        )
        dailyIcebreakerResult = result
        hasCompletedIcebreaker = true
        completedIcebreakerTaskTitle = dailyIcebreakerTask.title
        sparkPoints = min(100, sparkPoints + result.familiarityPoints)
        matchChatMessages.append(MatchChatMessage(text: "今日破冰卡：豆花選了「\(selectedAnswer.title)」", isOutgoing: true))
        matchChatMessages.append(MatchChatMessage(text: "超超選了「\(chaoChaoAnswer.title)」；你們的回答相似度 \(result.similarityPercent)%。", isOutgoing: false))
        return result
    }

    func cancelMatch() {
        isMatchCancelled = true
        isMatched = false
        hasMatchChat = false
        matchChatMessages = []
    }

    func blockMatch() {
        isMatchBlocked = true
        cancelMatch()
    }

    func unblockMatch() {
        isMatchBlocked = false
    }

    func reportMatch(_ reason: MatchReportReason) {
        reportedMatchReasons.append(reason)
    }

    func sendMeetupInvite() {
        guard sparkPoints >= 100 else { return }
        hasSentMeetupInvite = true
        matchChatMessages.append(MatchChatMessage(text: "發出了一對一見面邀請：先來一場 20 分鐘的平行散步吧！", isOutgoing: true))
    }

    func prepareMeetupInvitation() {
        hasPreparedMeetupInvitation = true
        hasSeenMeetupInvitationPrompt = true
    }

    func completeSafetyCheckIn() {
        hasCompletedSafetyCheckIn = true
    }

    func requestNextMeetup() {
        wantsNextMeetup = true
        hasMutualNextMeetup = true
        matchChatMessages.append(MatchChatMessage(text: "豆花覺得今天的散步很棒，希望下次能再一起出來走走！", isOutgoing: true))
    }

    func addInteractionRecord(
        with candidate: PlaydateCandidate,
        positiveTags: [String],
        wantsAnotherMeetup: Bool,
        note: String,
        hasSharedPhoto: Bool
    ) {
        addInteractionRecord(
            partnerDogName: candidate.name,
            partnerBreed: candidate.breed,
            recipientOwner: candidate.owner,
            recipientImageName: candidate.imageName,
            positiveTags: positiveTags,
            wantsAnotherMeetup: wantsAnotherMeetup,
            note: note,
            hasSharedPhoto: hasSharedPhoto
        )
    }

    func addInteractionRecord(
        partnerDogName: String,
        partnerBreed: String,
        recipientOwner: String,
        recipientImageName: String,
        positiveTags: [String],
        wantsAnotherMeetup: Bool,
        note: String,
        hasSharedPhoto: Bool
    ) {
        interactionRecords.append(
            InteractionRecord(
                partnerDogName: partnerDogName,
                partnerBreed: partnerBreed,
                positiveTags: positiveTags,
                wantsAnotherMeetup: wantsAnotherMeetup,
                note: note,
                hasSharedPhoto: hasSharedPhoto,
                createdAt: .now
            )
        )
        hasSentWarmFeedback = true
        lastWarmFeedbackTags = positiveTags
        lastWarmFeedbackNote = note
        lastWarmFeedbackHasPhoto = hasSharedPhoto
        lastWarmFeedbackRecipientName = partnerDogName
        lastWarmFeedbackRecipientOwner = recipientOwner
        lastWarmFeedbackRecipientImageName = recipientImageName
        sparkPoints = min(100, sparkPoints + 15 + (hasSharedPhoto ? 20 : 0))
        if wantsAnotherMeetup { requestNextMeetup() }
    }

    @discardableResult
    func createMeetup(_ meetup: MeetupDraft) -> String {
        createdMeetups.insert(meetup, at: 0)
        return meetupPlaceID(for: meetup)
    }

    func isUpcomingMeetupTaskCompleted(_ task: MeetupPreparationTask) -> Bool {
        completedUpcomingMeetupTaskIDs.contains(task.id)
    }

    func toggleUpcomingMeetupTask(_ task: MeetupPreparationTask) {
        if completedUpcomingMeetupTaskIDs.contains(task.id) {
            completedUpcomingMeetupTaskIDs.remove(task.id)
        } else {
            completedUpcomingMeetupTaskIDs.insert(task.id)
        }
    }

    func completedCount(for task: MeetupPreparationTask) -> Int {
        min(
            task.completedParticipantCount + (isUpcomingMeetupTaskCompleted(task) ? 1 : 0),
            task.totalParticipantCount
        )
    }

    var areUpcomingMeetupTasksCompleted: Bool {
        hasAcknowledgedUpcomingMeetupGuidance
    }

    func toggleUpcomingMeetupGuidanceAcknowledgement() {
        hasAcknowledgedUpcomingMeetupGuidance.toggle()
    }

    func updateUpcomingMeetup(
        title: String,
        startDate: Date,
        location: String,
        navigationLink: String,
        purpose: String,
        safetyPrinciples: [String],
        preparationNotes: String,
        coverPhotoData: Data?
    ) {
        if upcomingMeetup.traditionalChineseHostNote != purpose
            || upcomingMeetup.safetyPrinciples != safetyPrinciples
            || upcomingMeetup.preparationNotes != preparationNotes {
            hasAcknowledgedUpcomingMeetupGuidance = false
        }
        upcomingMeetup.title = title
        upcomingMeetup.traditionalChineseTitle = title
        upcomingMeetup.startDate = startDate
        upcomingMeetup.location = location
        upcomingMeetup.traditionalChineseLocation = location
        upcomingMeetup.hostNote = purpose
        upcomingMeetup.traditionalChineseHostNote = purpose
        upcomingMeetup.navigationLink = navigationLink
        upcomingMeetup.safetyPrinciples = safetyPrinciples
        upcomingMeetup.preparationNotes = preparationNotes
        upcomingMeetup.coverPhotoData = coverPhotoData
    }

    func completeGroupMeetupCheckIn() {
        hasCompletedGroupMeetupCheckIn = true
        hasTemporarilyLeftGroupMeetup = false
    }

    func openUpcomingMeetupCheckIn() {
        isUpcomingMeetupCheckInOpen = true
    }

    func temporarilyLeaveGroupMeetup() {
        hasTemporarilyLeftGroupMeetup = true
    }

    func endGroupMeetup() {
        hasEndedGroupMeetup = true
        hasTemporarilyLeftGroupMeetup = false
    }

    func deleteMeetup(id: UUID) {
        createdMeetups.removeAll { $0.id == id }
    }

    func meetupPlaceID(for meetup: MeetupDraft) -> String {
        "created-meetup-\(meetup.id.uuidString)"
    }

    private func meetupPlace(for meetup: MeetupDraft) -> Place? {
        guard let venue = meetupVenues.first(where: {
            $0.name == meetup.location || $0.traditionalChineseName == meetup.location
        }),
              let basePlace = places.first(where: { $0.id == venue.mapPlaceID }) else {
            return nil
        }

        let category: String
        switch meetup.activityTypeID {
        case "dining": category = "Indoor dog meetup"
        case "grass-play": category = "Grass playtime"
        default: category = "Dog meetup"
        }

        return Place(
            id: meetupPlaceID(for: meetup),
            name: meetup.title,
            category: category,
            nearbyCategory: .meetups,
            region: basePlace.region,
            walk: basePlace.walk,
            walkMinutes: basePlace.walkMinutes,
            imageName: basePlace.imageName,
            rules: meetup.safetyTagIDs.contains("Leash on") ? [.indoorLeash] : [],
            verified: "just now",
            dogAccess: basePlace.dogAccess,
            verificationLevel: .hostCreated,
            lastConfirmed: "Just now",
            verificationSource: "Created by host",
            acceptsLargeDogs: true,
            isOpenNow: true,
            latitude: basePlace.latitude,
            longitude: basePlace.longitude,
            address: basePlace.address,
            facilities: basePlace.facilities,
            intentKeywords: "dog meetup \(basePlace.intentKeywords)"
        )
    }
}

struct MatchChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isOutgoing: Bool
}

struct DailyIcebreakerOption: Identifiable, Hashable {
    let id: String
    let title: String
    let similarityPercent: Int
    let familiarityPoints: Int
}

struct DailyIcebreakerTask: Identifiable {
    let id: String
    let title: String
    let prompt: String
    let chaoChaoAnswerID: String
    let options: [DailyIcebreakerOption]

    static let all = [
        DailyIcebreakerTask(
            id: "first-hello",
            title: "第一次見面，怎麼開始最舒服？",
            prompt: "如果第一次和新狗朋友見面，豆花最喜歡怎麼開始？",
            chaoChaoAnswerID: "parallel-walk",
            options: [
                DailyIcebreakerOption(id: "parallel-walk", title: "先並排散步", similarityPercent: 100, familiarityPoints: 25),
                DailyIcebreakerOption(id: "observe", title: "先遠遠觀察", similarityPercent: 70, familiarityPoints: 22),
                DailyIcebreakerOption(id: "free-play", title: "直接一起玩", similarityPercent: 40, familiarityPoints: 20)
            ]
        ),
        DailyIcebreakerTask(
            id: "rest-style",
            title: "散步中想休息時…",
            prompt: "豆花比較喜歡用哪種方式補充能量？",
            chaoChaoAnswerID: "quiet-corner",
            options: [
                DailyIcebreakerOption(id: "quiet-corner", title: "找個安靜角落休息", similarityPercent: 100, familiarityPoints: 25),
                DailyIcebreakerOption(id: "slow-walk", title: "放慢步調繼續走", similarityPercent: 70, familiarityPoints: 22),
                DailyIcebreakerOption(id: "keep-playing", title: "繼續玩不休息", similarityPercent: 40, familiarityPoints: 20)
            ]
        ),
        DailyIcebreakerTask(
            id: "favorite-outing",
            title: "理想的狗狗約會",
            prompt: "選一個最適合豆花的週末相處方式。",
            chaoChaoAnswerID: "calm-park",
            options: [
                DailyIcebreakerOption(id: "calm-park", title: "安靜的公園散步", similarityPercent: 100, familiarityPoints: 25),
                DailyIcebreakerOption(id: "pet-cafe", title: "寵物友善咖啡廳", similarityPercent: 70, familiarityPoints: 22),
                DailyIcebreakerOption(id: "busy-event", title: "熱鬧的多人活動", similarityPercent: 40, familiarityPoints: 20)
            ]
        ),
        DailyIcebreakerTask(
            id: "new-friend-signal",
            title: "想靠近新朋友時…",
            prompt: "豆花通常會用什麼方式表示想繼續認識？",
            chaoChaoAnswerID: "stay-nearby",
            options: [
                DailyIcebreakerOption(id: "stay-nearby", title: "在附近慢慢跟著走", similarityPercent: 100, familiarityPoints: 25),
                DailyIcebreakerOption(id: "sniff-briefly", title: "短暫聞聞再退一步", similarityPercent: 70, familiarityPoints: 22),
                DailyIcebreakerOption(id: "bounce-in", title: "立刻撲過去玩", similarityPercent: 40, familiarityPoints: 20)
            ]
        ),
        DailyIcebreakerTask(
            id: "favorite-reward",
            title: "今天的小確幸",
            prompt: "散步結束後，哪件事最能讓豆花感到滿足？",
            chaoChaoAnswerID: "quiet-rest",
            options: [
                DailyIcebreakerOption(id: "quiet-rest", title: "回家安靜休息", similarityPercent: 100, familiarityPoints: 25),
                DailyIcebreakerOption(id: "small-treat", title: "來一份小點心", similarityPercent: 70, familiarityPoints: 22),
                DailyIcebreakerOption(id: "more-adventure", title: "再去一個新地方", similarityPercent: 40, familiarityPoints: 20)
            ]
        )
    ]
}

struct DailyIcebreakerResult {
    let taskID: String
    let taskTitle: String
    let prompt: String
    let tofuAnswer: DailyIcebreakerOption
    let chaoChaoAnswer: DailyIcebreakerOption
    let similarityPercent: Int
    let familiarityPoints: Int
    let completedAt: Date
}

struct MeetupGroupMessage: Identifiable {
    let id = UUID()
    let senderName: String
    let text: String
    let isOutgoing: Bool
}

struct MeetupActivityType: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let traditionalChineseTitle: String

    func localizedTitle(_ language: SnootsLanguage) -> String {
        language.text(title, traditionalChineseTitle)
    }
}

struct MeetupVenue: Identifiable {
    let id: String
    let mapPlaceID: String
    let name: String
    let traditionalChineseName: String

    func localizedName(_ language: SnootsLanguage) -> String {
        language.text(name, traditionalChineseName)
    }
}

struct MeetupSafetyOption: Identifiable {
    let id: String
    let title: String
    let traditionalChineseTitle: String

    func localizedTitle(_ language: SnootsLanguage) -> String {
        language.text(title, traditionalChineseTitle)
    }
}

struct MeetupDraft: Identifiable {
    let id = UUID()
    let title: String
    let activityTypeID: String
    let location: String
    let navigationLink: String
    let startDate: Date
    let attendeeLimit: Int
    let requiresApproval: Bool
    let safetyTagIDs: [String]
    let notes: String
    let hasCoverPhoto: Bool
}

struct UpcomingMeetup {
    var title: String
    var traditionalChineseTitle: String
    let organizerName: String
    let traditionalChineseOrganizerName: String
    var startDate: Date
    let durationHours: Int
    var location: String
    var traditionalChineseLocation: String
    var hostNote: String
    var traditionalChineseHostNote: String
    let participants: [MeetupParticipant]
    let totalParticipantCount: Int
    let readyParticipantCount: Int
    let preparationTasks: [MeetupPreparationTask]
    var coverPhotoData: Data? = nil
    var navigationLink = "https://maps.app.goo.gl/XwG5XF2fABV3pgEb7"
    var safetyPrinciples = ["不強迫社交", "不擅自餵食", "全程使用牽繩"]
    var preparationNotes = "請帶好牽繩、飲水與拾便袋，提早 10 分鐘抵達集合地點。若狗狗需要更多空間，請先與發起人聯繫。"

    func localizedTitle(_ language: SnootsLanguage) -> String {
        language.text(title, traditionalChineseTitle)
    }

    func localizedLocation(_ language: SnootsLanguage) -> String {
        language.text(location, traditionalChineseLocation)
    }

    func localizedOrganizerName(_ language: SnootsLanguage) -> String {
        language.text(organizerName, traditionalChineseOrganizerName)
    }

    func localizedHostNote(_ language: SnootsLanguage) -> String {
        language.text(hostNote, traditionalChineseHostNote)
    }
}

struct MeetupParticipant: Identifiable {
    let name: String
    let traditionalChineseName: String
    let imageName: String
    let breed: String
    let age: String
    let size: String
    let summary: String
    let healthSummary: String
    let safetyTagIDs: [String]

    var id: String { name }

    func localizedName(_ language: SnootsLanguage) -> String {
        language.text(name, traditionalChineseName)
    }
}

struct MeetupPreparationTask: Identifiable {
    let id: String
    let title: String
    let traditionalChineseTitle: String
    let completedParticipantCount: Int
    let totalParticipantCount: Int
    let symbol: String

    func localizedTitle(_ language: SnootsLanguage) -> String {
        language.text(title, traditionalChineseTitle)
    }
}

struct ParentProfile {
    var name: String
    var petName: String
    let trustScore: Int
    var neighborhood: String
    var email = ""
    var ownerMessage = "比較慢熱，希望先保持舒服的距離，再一起散步認識彼此。"
}

struct PetProfile {
    var name: String
    let imageName: String
    var breed: String
    var breedMappingPending = false
    var age: String
    var size: String
    var sex: String
    var isNeutered: Bool
    var socialStyle: String
    var summary: String
    var traits: [String]
    let healthStatus: String
    var photoData: Data? = nil
    var touchBoundary = "尚未填寫"
    var resourceGuarding = "尚未填寫"
    var energyLevel = "尚未填寫"
    var preferredMeetingEnvironments: [String] = []
    var vaccineSummary = "尚未填寫"
    var emergencyPhone = "尚未填寫"
    var leashHabit = "尚未填寫"
    var matchingProfile = DogMatchingProfile()
}

struct DogMatchingProfile: Codable {
    var birthDate: Date?
    // Required for activity recommendations; "無" is exclusive of other selections.
    var activityNeeds: [String] = []
    // Empty means no health details were shared, not that no condition exists.
    var socialHealthConditions: [String] = []
    var activityPreferences: [String] = []
    var activityDescription = ""
    var activityKeywords: [String] = []
    var hasSocialNotes: Bool?
    var socialFeatures: [String] = []
    var meetingEnvironments: [String] = []
    var firstMeetingPace: String?
    var interactionScenario: String?
    var interactionFeatures: [String] = []
    var protectionAnswers: [String: String] = [:]
}

struct FeedingMonitor {
    let isOnline: Bool
    let lastFedHoursAgo: Int
    let waterIntakeMilliliters: Int
    let waterGoalMilliliters: Int

    var waterProgress: Double {
        min(Double(waterIntakeMilliliters) / Double(waterGoalMilliliters), 1)
    }
}

struct SocialPost: Identifiable {
    enum Kind { case photo, discussion }

    let id = UUID()
    let owner: String
    let petName: String
    let location: String
    let timeAgo: String
    let body: String
    let declarations: [String]
    let likes: Int
    var comments: Int
    let kind: Kind
    let photoName: String?
    let title: String
    let month: Int
    let day: Int
    let galleryPhotoNames: [String]
    var replies: [SocialPostComment]

    func localizedTimeAgo(_ language: SnootsLanguage) -> String {
        switch timeAgo {
        case "12m": language.text(timeAgo, "12 分鐘前")
        case "1h": language.text(timeAgo, "1 小時前")
        default: timeAgo
        }
    }

    func localizedBody(_ language: SnootsLanguage) -> String {
        switch owner {
        case "Yuna":
            language.text(body, "第一次在大安森林公園平靜散步。Nori 使用長牽繩並保有足夠空間，表現得很棒。")
        case "Milo":
            language.text(body, "夕陽時的開心奔跑，接著沿著河岸慢慢聞一聞。")
        default:
            body
        }
    }

    func localizedDeclarations(_ language: SnootsLanguage) -> [String] {
        declarations.map { declaration in
            switch declaration {
            case "Leash on": language.text(declaration, "已繫牽繩")
            case "Slow introductions": language.text(declaration, "慢慢認識")
            case "Adult dogs": language.text(declaration, "偏好成犬")
            case "Friendly hello": language.text(declaration, "友善打招呼")
            case "Sunset walk": language.text(declaration, "夕陽散步")
            default: declaration
            }
        }
    }
}

struct SocialPostComment: Identifiable {
    let id = UUID()
    let author: String
    let text: String
}

struct PlaydateCandidate {
    let name: String
    let age: String
    let owner: String
    let distance: String
    let imageName: String
    let photoNames: [String]
    let compatibility: [String]
    let accountability: String
    let intro: String
    let breed: String
    let size: String
    let sex: String
    let isNeutered: Bool
    let strangerDogReaction: String
    let energyLevel: String
    let meetingEnvironments: [String]
    let healthSummary: String
    let isRabiesVaccinated: Bool
    let hasMonthlyParasitePrevention: Bool
}

enum MatchReportReason: String, CaseIterable, Identifiable {
    case unleashedDog
    case verbalHarassment
    case undisclosedAggression
    case fakeAccount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unleashedDog: "現場未繫牽繩／控管不當"
        case .verbalHarassment: "言語騷擾"
        case .undisclosedAggression: "狗狗有攻擊行為但未事先告知"
        case .fakeAccount: "假帳號"
        }
    }
}

struct InteractionRecord: Identifiable {
    let id = UUID()
    let partnerDogName: String
    let partnerBreed: String
    let positiveTags: [String]
    let wantsAnotherMeetup: Bool
    let note: String
    let hasSharedPhoto: Bool
    let createdAt: Date
}

struct CareStep: Identifiable {
    let id = UUID()
    let title: String
    let instruction: String
    let symbol: String
}

struct Clinic {
    let name: String
    let eta: String
    let address: String
    let handoff: String

    func localizedName(_ language: SnootsLanguage) -> String {
        language.text(name, "大安夜間動物診所")
    }

    func localizedETA(_ language: SnootsLanguage) -> String {
        language.text(eta, "8 分鐘")
    }

    func localizedAddress(_ language: SnootsLanguage) -> String {
        language.text(address, "大安區復興南路 104 號")
    }

    func localizedHandoff(_ language: SnootsLanguage) -> String {
        language.text(handoff, "已準備症狀與可能接觸物摘要")
    }
}

struct Place: Identifiable {
    let id: String
    let name: String
    let category: String
    let nearbyCategory: NearbyCategory
    let region: NearbyRegion
    let walk: String
    let walkMinutes: Int
    let imageName: String
    let rules: [PlaceRule]
    let verified: String
    let dogAccess: DogAccess
    let verificationLevel: VerificationLevel
    let lastConfirmed: String
    let verificationSource: String
    let acceptsLargeDogs: Bool
    let isOpenNow: Bool
    var hasLiveStatus: Bool = true
    let latitude: Double
    let longitude: Double
    let address: String
    let facilities: [PlaceFacility]
    let intentKeywords: String

    func localizedName(_ language: SnootsLanguage) -> String {
        switch id {
        case "companion": language.text(name, "伴伴咖啡")
        case "terrace": language.text(name, "露台小桌")
        case "pages": language.text(name, "毛孩書頁吧")
        case "morning-walk": language.text(name, "大安晨間狗狗散步")
        case "rainy-club": language.text(name, "雨天幼犬同樂會")
        case "daan-forest": language.text(name, "大安森林公園")
        case "xinyi-dog-park": language.text(name, "信義河濱狗狗公園")
        case "daan-night": language.text(name, "大安夜間動物診所")
        case "xinyi-vet": language.text(name, "信義動物醫院")
        case _ where id.hasPrefix("created-meetup-"): name
        default: name
        }
    }

    func localizedAddress(_ language: SnootsLanguage) -> String {
        switch id {
        case "companion": language.text(address, "中正區羅斯福路三段 181 巷 18 號")
        case "terrace": language.text(address, "大安區永康街 42 號")
        case "pages": language.text(address, "大安區和平東路 243 巷 9 號")
        case "morning-walk": language.text(address, "大安森林公園東門")
        case "rainy-club": language.text(address, "大安區光復南路 201 巷 15 號")
        case "daan-forest": language.text(address, "大安區新生南路二段 1 號")
        case "xinyi-dog-park": language.text(address, "信義區河濱公園")
        case "daan-night": language.text(address, "大安區復興南路 104 號")
        case "xinyi-vet": language.text(address, "信義區信義路五段 98 號")
        default: address
        }
    }

    func localizedVerificationSource(_ language: SnootsLanguage) -> String {
        switch verificationSource {
        case "Venue confirmed": language.text(verificationSource, "場地方確認")
        case "Community confirmed": language.text(verificationSource, "社群確認")
        case "Community report": language.text(verificationSource, "社群回報")
        case "Host confirmed": language.text(verificationSource, "主辦方確認")
        case "Host and venue confirmed": language.text(verificationSource, "主辦方與場地方確認")
        case "Clinic confirmed": language.text(verificationSource, "診所確認")
        case "Created by host": language.text(verificationSource, "由主辦人建立")
        default: verificationSource
        }
    }

    func localizedLastConfirmed(_ language: SnootsLanguage) -> String {
        switch lastConfirmed {
        case "Just now": return language.text(lastConfirmed, "剛剛")
        case "17 Jul 2026": return language.text(lastConfirmed, "2026 年 7 月 17 日")
        case "16 Jul 2026": return language.text(lastConfirmed, "2026 年 7 月 16 日")
        case "14 Jul 2026": return language.text(lastConfirmed, "2026 年 7 月 14 日")
        case "12 Jul 2026": return language.text(lastConfirmed, "2026 年 7 月 12 日")
        case "10 Jul 2026": return language.text(lastConfirmed, "2026 年 7 月 10 日")
        default:
            guard let date = ISO8601DateFormatter().date(from: lastConfirmed) else { return lastConfirmed }
            return date.formatted(
                Date.FormatStyle(date: .long, time: .omitted)
                    .locale(language.locale)
            )
        }
    }

    func localizedCategory(_ language: SnootsLanguage) -> String {
        switch category {
        case "Cafe": language.text("Cafe", "咖啡廳")
        case "Bistro": language.text("Bistro", "餐酒館")
        case "Book bar": language.text("Book bar", "書吧")
        case "Leashed group walk": language.text("Leashed group walk", "牽繩團體散步")
        case "Indoor dog meetup": language.text("Indoor dog meetup", "室內狗聚")
        case "Dog meetup": language.text("Dog meetup", "狗聚")
        case "Urban park": language.text("Urban park", "城市公園")
        case "Dog park": language.text("Dog park", "狗狗公園")
        case "Emergency veterinary clinic": language.text("Emergency veterinary clinic", "急診獸醫診所")
        case "Veterinary hospital": language.text("Veterinary hospital", "動物醫院")
        case "Restaurant": language.text("Restaurant", "用餐地點")
        case "Park": language.text("Park", "公園")
        default: category
        }
    }

    func localizedWalk(_ language: SnootsLanguage) -> String {
        language.text(walk, "步行 \(walkMinutes) 分鐘")
    }

    func sizeRule(_ language: SnootsLanguage) -> String {
        acceptsLargeDogs ? language.text("Large dogs accepted.", "接受大型犬。") : language.text("Small dogs only.", "僅限小型犬。")
    }

    func equipmentRule(_ language: SnootsLanguage) -> String {
        language.text("Leash required.", "需要牽繩。")
    }

    func seatingRule(_ language: SnootsLanguage) -> String {
        language.text("Dogs stay on the floor; no seats or tables.", "狗狗需待在地面，不可上座位或桌面。")
    }

    func timeRule(_ language: SnootsLanguage) -> String {
        dogAccess == .restrictionsApply ? language.text("Please check the visit time with staff.", "請先向現場人員確認可入場時段。") : language.text("No regular time restriction reported.", "目前未回報固定時段限制。")
    }

    func policySummary(_ language: SnootsLanguage) -> String {
        language.text("\(dogAccess.detail(language)) \(sizeRule(language)) \(equipmentRule(language)) Policy confirmed by \(verificationSource.lowercased()) on \(lastConfirmed).", "\(dogAccess.detail(language)) \(sizeRule(language)) \(equipmentRule(language)) 政策由 \(localizedVerificationSource(language)) 於 \(localizedLastConfirmed(language)) 確認。")
    }

    func openingHours(_ language: SnootsLanguage) -> String {
        guard hasLiveStatus else { return language.text("Live hours unavailable", "暫無即時營業資訊") }
        return isOpenNow ? language.text("Open until 21:00", "營業至 21:00") : language.text("Opens at 10:00", "10:00 開始營業")
    }

    func realWorldNotes(_ language: SnootsLanguage) -> [String] {
        acceptsLargeDogs
            ? [language.text("Tight indoor aisles", "室內走道較窄"), language.text("Busy after 2pm", "下午 2 點後較繁忙")]
            : [language.text("Best for smaller dogs", "較適合小型犬"), language.text("Bring a calm-down kit", "建議攜帶安撫用品")]
    }
}

extension MapPlace {
    func asNearbyPlace() -> Place? {
        guard let coordinate else { return nil }

        let nearbyCategory: NearbyCategory
        let displayCategory: String
        let imageName: String
        switch category {
        case .meetup:
            nearbyCategory = .meetups
            displayCategory = "Dog meetup"
            imageName = "Nori"
        case .restaurant:
            nearbyCategory = .dining
            displayCategory = "Restaurant"
            imageName = "CompanionCafe"
        case .park:
            nearbyCategory = .parks
            displayCategory = "Park"
            imageName = "Mochi"
        case .hospital:
            nearbyCategory = .vets
            displayCategory = "Veterinary hospital"
            imageName = "TerraceTable"
        }

        let nearbyRegion: NearbyRegion
        let regionText = [area, location].compactMap { $0 }.joined()
        if regionText.contains("大安") {
            nearbyRegion = .daan
        } else if regionText.contains("信義") {
            nearbyRegion = .xinyi
        } else if regionText.contains("中正") {
            nearbyRegion = .zhongzheng
        } else {
            nearbyRegion = .currentLocation
        }

        let dogAccess: DogAccess
        switch dogAccessLabel {
        case "indoor_ok": dogAccess = .indoorOK
        case "outdoor_only": dogAccess = .outdoorOnly
        case "carrier_required": dogAccess = .carrierRequired
        default: dogAccess = .restrictionsApply
        }

        let verification: VerificationLevel
        switch verificationLevel {
        case "venue_confirmed": verification = .venueConfirmed
        case "community_confirmed": verification = .communityConfirmed
        default: verification = .needsReconfirmation
        }

        var rules: [PlaceRule] = []
        if filterIDs.contains(where: { $0.hasSuffix("leash_required") }) { rules.append(.indoorLeash) }
        if dogAccess == .outdoorOnly { rules.append(.outdoorOnly) }
        if filterIDs.contains("park.shade_canopy") { rules.append(.waterBowl) }

        var facilities: [PlaceFacility] = []
        if filterIDs.contains("park.shade_canopy") { facilities.append(.shade) }
        if filterIDs.contains("park.seating") { facilities.append(.outdoorSeating) }

        let minutes = max(1, Int(ceil((distanceMeters ?? 0) / 80)))
        let confirmation = verifiedAt ?? ""
        let source = verification == .venueConfirmed ? "Venue confirmed" : verification == .communityConfirmed ? "Community confirmed" : "Community report"

        return Place(
            id: id,
            name: name,
            category: displayCategory,
            nearbyCategory: nearbyCategory,
            region: nearbyRegion,
            walk: "\(minutes) min walk",
            walkMinutes: minutes,
            imageName: imageName,
            rules: rules,
            verified: confirmation,
            dogAccess: dogAccess,
            verificationLevel: verification,
            lastConfirmed: confirmation,
            verificationSource: source,
            acceptsLargeDogs: filterIDs.contains("dining.large_dog") || category != .restaurant,
            isOpenNow: false,
            hasLiveStatus: false,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: location ?? area ?? "",
            facilities: facilities,
            intentKeywords: ([policySummary] + filterIDs.sorted()).compactMap { $0 }.joined(separator: " ")
        )
    }
}

enum DogAccess: String, CaseIterable {
    case indoorOK, outdoorOnly, carrierRequired, restrictionsApply

    func label(_ language: SnootsLanguage) -> String {
        switch self {
        case .indoorOK: language.text("Indoor OK", "可進室內")
        case .outdoorOnly: language.text("Outdoor only", "僅限戶外")
        case .carrierRequired: language.text("Carrier required", "需使用提籠")
        case .restrictionsApply: language.text("Restrictions apply", "須遵守限制")
        }
    }

    func detail(_ language: SnootsLanguage) -> String {
        switch self {
        case .indoorOK: language.text("Indoor access allowed.", "可進入室內。")
        case .outdoorOnly: language.text("Outdoor access only.", "僅限戶外區域。")
        case .carrierRequired: language.text("Indoor access with a carrier required.", "進室內時必須使用提籠。")
        case .restrictionsApply: language.text("Access depends on staff instructions or conditions.", "入場需依現場人員指示或條件辦理。")
        }
    }
}

enum VerificationLevel: String {
    case venueConfirmed, communityConfirmed, needsReconfirmation, hostCreated

    func label(_ language: SnootsLanguage) -> String {
        switch self {
        case .venueConfirmed: language.text("Venue confirmed", "場地方已確認")
        case .communityConfirmed: language.text("Community confirmed", "社群已確認")
        case .needsReconfirmation: language.text("Needs reconfirmation", "需再次確認")
        case .hostCreated: language.text("Created by you", "由你建立")
        }
    }
}

enum PlaceFacility: CaseIterable {
    case waterBowl, wasteBin, shade, outdoorSeating, parking

    func label(_ language: SnootsLanguage) -> String {
        switch self {
        case .waterBowl: language.text("Water bowl", "飲水碗")
        case .wasteBin: language.text("Waste bin", "便袋垃圾桶")
        case .shade: language.text("Shade", "遮蔭")
        case .outdoorSeating: language.text("Outdoor seating", "戶外座位")
        case .parking: language.text("Parking", "停車")
        }
    }
}

enum PlaceRule: String, Identifiable {
    case stroller, indoorLeash, under15kg, seatCover, outdoorOnly, waterBowl, quietHours

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .stroller: "Stroller OK"
        case .indoorLeash: "Leash inside"
        case .under15kg: "Under 15 kg"
        case .seatCover: "Seat cover"
        case .outdoorOnly: "Patio only"
        case .waterBowl: "Water bowls"
        case .quietHours: "Quiet hours"
        }
    }

    var label: String {
        switch self {
        case .stroller: "Strollers welcome at the entry"
        case .indoorLeash: "Leash required indoors"
        case .under15kg: "Dogs under 15 kg only"
        case .seatCover: "Bring a seat cover for bench seating"
        case .outdoorOnly: "Dogs are welcome on the outdoor patio only"
        case .waterBowl: "Water bowls available on request"
        case .quietHours: "Quiet hours after 7pm"
        }
    }

    var symbol: String {
        switch self {
        case .stroller: "stroller.fill"
        case .indoorLeash: "link"
        case .under15kg: "scalemass.fill"
        case .seatCover: "chair.lounge.fill"
        case .outdoorOnly: "sun.max.fill"
        case .waterBowl: "drop.fill"
        case .quietHours: "moon.stars.fill"
        }
    }
}

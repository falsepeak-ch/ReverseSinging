//
//  HelpContentTests.swift
//  ReverseSinging
//
//  Every question in Help has words, in every language the app ships
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Help Content") @MainActor
struct HelpContentTests {

    /// A missing key shows the key itself on screen, `help.dub.3.q`, which reads as a bug.
    @Test(arguments: HelpTopic.allCases)
    func everyArticleHasAQuestionAndAnAnswer(topic: HelpTopic) {
        for article in topic.articles {
            #expect(!article.question.hasPrefix("help."), "\(article.id) has no question")
            #expect(!article.answer.hasPrefix("help."), "\(article.id) has no answer")
        }
    }

    @Test func searchFindsAnswersNotJustQuestions() {
        let results = HelpTopic.allCases.flatMap(\.articles).filter { $0.matches("count-in") }
        #expect(results.contains { $0.id == "dub.1" })
    }

    @Test func searchIgnoresCaseAndAccents() {
        let article = HelpArticle(topic: .gettingStarted, number: 1)
        #expect(article.matches("DUBLOON"))
    }

    @Test func openingHelpFromAGameOpensThatGamesFirstAnswer() {
        let viewModel = HelpViewModel(topic: .imitate)
        #expect(viewModel.topics.first == .imitate)
        #expect(viewModel.isExpanded(HelpArticle(topic: .imitate, number: 1)))
        #expect(!viewModel.isExpanded(HelpArticle(topic: .imitate, number: 2)))
    }

    /// Every language carries exactly the keys English does, so nothing new ships half
    /// translated and nothing stale lingers.
    @Test func everyLanguageHasEveryString() throws {
        let english = try keys(for: "en")
        let others = Bundle.main.localizations.filter { $0 != "en" && $0 != "Base" }
        #expect(others.count >= 20)

        for localization in others {
            let theirs = try keys(for: localization)
            #expect(english.subtracting(theirs).isEmpty, "\(localization) is missing \(english.subtracting(theirs).sorted())")
            #expect(theirs.subtracting(english).isEmpty, "\(localization) has extra \(theirs.subtracting(english).sorted())")
        }
    }

    private func keys(for localization: String) throws -> Set<String> {
        let path = try #require(Bundle.main.path(
            forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: localization
        ))
        let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
        return Set(table.keys)
    }
}

#ifndef OPENMP_LIBOMPTARGET_TEST_OMPTEST_OMPTEST_H
#define OPENMP_LIBOMPTARGET_TEST_OMPTEST_OMPTEST_H

#include "OmptAssertEvent.h"
#include "OmptAsserter.h"
#include "OmptCallbackHandler.h"

#include <cassert>
#include <iostream>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include <omp-tools.h>

#define XQUOTE(str) QUOTE(str)
#define QUOTE(str) #str
#define BAR_IT(Id) Id##_

#ifdef __cplusplus
extern "C" {
#endif
ompt_start_tool_result_t *ompt_start_tool(unsigned int omp_version,
                                          const char *runtime_version);
#ifdef __cplusplus
}
#endif

struct Error {
  operator bool() { return fail; }
  bool fail;
};

enum class AssertState { pass, fail };

/// A pretty crude test case abstraction
struct TestCase {
  TestCase(const std::string name) : Name(name) {}
  virtual ~TestCase() {}
  std::string Name;
  AssertState assertState;
  Error exec() {
    OmptCallbackHandler::get().subscribe(&SequenceAsserter);
    OmptCallbackHandler::get().subscribe(&EventAsserter);

    Error e;
    e.fail = false;
    execImpl();

    // We remove subscribers to not be notified of events after our test case
    // finished.
    OmptCallbackHandler::get().clearSubscribers();
    if (assertState == AssertState::fail)
      e.fail = true;
    return e;
  };

  virtual void execImpl() { assert(false && "Allocating base class"); }

  // TODO: Should the asserter get a pointer to "their" test case? Probably, as
  // that would allow them to manipulate the Error or AssertState.
  OmptSequencedAsserter SequenceAsserter;
  OmptEventAsserter EventAsserter;
};

void failAssertImpl(TestCase &tc) { tc.assertState = AssertState::fail; }
void passAssertImpl(TestCase &tc) { tc.assertState = AssertState::pass; }

/// A pretty crude test suite abstraction
struct TestSuite {
  using C = std::vector<std::unique_ptr<TestCase>>;

  std::string Name;
  TestSuite() = default;
  TestSuite(const TestSuite &o) = delete;
  TestSuite(TestSuite &&o) {
    Name = o.Name;
    TestCases.swap(o.TestCases);
  }

  void setup() {}
  void teardown() {}

  C::iterator begin() { return TestCases.begin(); }
  C::iterator end() { return TestCases.end(); }

  C TestCases;
};

/// Static class used to register all test cases and provide them to the driver
struct TestRegistrar {
  static TestRegistrar &get() {
    static TestRegistrar TR;
    return TR;
  }

  static std::vector<TestSuite> getTestSuites() {
    std::vector<TestSuite> TSs;

    for (auto &[k, v] : Tests)
      TSs.emplace_back(std::move(v));

    return TSs;
  }

  static void addCaseToSuite(TestCase *TC, std::string TSName) {
    auto &TS = Tests[TSName];
    if (TS.Name.empty())
      TS.Name = TSName;

    TS.TestCases.emplace_back(TC);
  }

private:
  TestRegistrar() = default;
  TestRegistrar(const TestRegistrar &o) = delete;
  TestRegistrar operator=(const TestRegistrar &o) = delete;

  static std::unordered_map<std::string, TestSuite> Tests;
};

/// Hack to register test cases
struct Registerer {
  Registerer(TestCase *TC, const std::string SuiteName) {
    std::cout << "Adding " << TC->Name << " to " << SuiteName << std::endl;
    TestRegistrar::get().addCaseToSuite(TC, SuiteName);
  }
};

/// Eventually executes all test suites and cases, should contain logic to skip
/// stuff if needed
struct Runner {
  Runner() : TestSuites(TestRegistrar::get().getTestSuites()) {}
  int run() {
    for (auto &TS : TestSuites) {
      std::cout << "\n======\nExecuting for " << TS.Name << std::endl;
      TS.setup();
      for (auto &TC : TS) {
        std::cout << "\nExecuting " << TC->Name << std::endl;
        if (Error err = TC->exec()) {
          reportError();
          abortOrKeepGoing();
        }
      }
      TS.teardown();
    }
    return 0;
  }

  void reportError() {}
  void abortOrKeepGoing() {}

  std::vector<TestSuite> TestSuites;
};

/// ASSERT MACROS TO BE USED BY THE USER
#define OMPT_EVENT_ASSERT(Event, ...)
#define OMPT_EVENT_ASSERT_DISABLE() this->EventAsserter.setActive(false);
#define OMPT_EVENT_ASSERT_ENABLE() this->EventAsserter.setActive(true);
#define OMPT_SEQ_ASSERT(Event, ...)
#define OMPT_SEQ_ASSERT_DISABLE() this->SequenceAsserter.setActive(false);
#define OMPT_SEQ_ASSERT_ENABLE() this->SequenceAsserter.setActive(true);
#define OMPT_SEQ_ASSERT_NOT(Event, ...)

/// MACRO TO DEFINE A TESTSUITE + TESTCASE (like GoogleTest does)
#define OMPTTESTCASE(SuiteName, CaseName)                                      \
  struct SuiteName##_##CaseName : public TestCase {                            \
    SuiteName##_##CaseName() : TestCase(XQUOTE(CaseName)) {}                   \
    virtual void execImpl() override;                                          \
  };                                                                           \
  static Registerer R_##SuiteName##CaseName(new SuiteName##_##CaseName(),      \
                                            #SuiteName);                       \
  void SuiteName##_##CaseName::execImpl()

#endif // include guard

#ifndef OPENMP_LIBOMPTARGET_TEST_OMPTEST_OMPTASSERTER_H
#define OPENMP_LIBOMPTARGET_TEST_OMPTEST_OMPTASSERTER_H

#include "OmptAssertEvent.h"

#include <algorithm>
#include <cassert>
#include <iostream>
#include <set>
#include <vector>

/// General base class for the subscriber/notification pattern in
/// OmptCallbachHandler. Derived classes need to implement the notify method.
struct OmptListener {
  /// Called for each registered OMPT event of the OmptCallbackHandler
  virtual void notify(omptest::OmptAssertEvent &&AE) = 0;
};

/// Base class for asserting on OMPT events
class OmptAsserter : public OmptListener {
public:
  virtual void insert(omptest::OmptAssertEvent &&AE) {
    assert(false && "Base class 'insert' has undefined semantics.");
  }

  // Called from the CallbackHandler with a corresponding AssertEvent to which
  // callback was handled.
  void notify(omptest::OmptAssertEvent &&AE) {
    this->notifyImpl(std::move(AE));
  }

  /// Implemented in subclasses to implement what should actually be done with
  /// the notification.
  virtual void notifyImpl(omptest::OmptAssertEvent &&AE) = 0;

  /// Report an error for a single event
  void reportError(const omptest::OmptAssertEvent &OffendingEvent,
                   const std::string &Message) {
    std::cerr << "[Error] " << Message
              << "\nOffending Event: " << OffendingEvent.getEventName()
              << std::endl;
  }

  void reportError(const omptest::OmptAssertEvent &AwaitedEvent,
                   const omptest::OmptAssertEvent &OffendingEvent,
                   const std::string &Message) {
    std::cerr << "[Assert Error]: Awaited event " << AwaitedEvent.getEventName()
              << "\nGot: " << OffendingEvent.getEventName() << "\n"
              << Message << std::endl;
  }

  /// Control whether this asserter should be considered 'active'.
  void setActive(bool Enabled) { Active = Enabled; }

  /// Check if this asserter is considered 'active'.
  bool isActive() { return Active; }

  virtual omptest::AssertState getState() { return State; }

protected:
  omptest::AssertState State{omptest::AssertState::pass};

private:
  bool Active{true};
};

/// Class that can assert in a sequenced fashion, i.e., events hace to occur in
/// the order they were registered
struct OmptSequencedAsserter : public OmptAsserter {
  OmptSequencedAsserter() : NextEvent(0), Events() {}

  /// Add the event to the in-sequence set of events that the asserter should
  /// check for.
  void insert(omptest::OmptAssertEvent &&AE) override {
    Events.emplace_back(std::move(AE));
  }

  /// Implements the asserter's actual logic
  virtual void notifyImpl(omptest::OmptAssertEvent &&AE) override {
    // Ignore notifications while inactive
    if (!isActive())
      return;

    if (NextEvent >= Events.size()) {
      reportError(AE, "[OmptSequencedAsserter] Too many events to check. "
                      "Only asserted " +
                          std::to_string(Events.size()) + " event.");
      State = omptest::AssertState::fail;
      return;
    }

    auto &E = Events[NextEvent++];
    if (E == AE)
      return;

    reportError(E, AE, "[OmptSequencedAsserter] The events are not equal");
    State = omptest::AssertState::fail;
  }

  omptest::AssertState getState() override {
    // This is called after the testcase executed.
    // Once, reached, no more events should be in the queue
    if (NextEvent < Events.size())
      State = omptest::AssertState::fail;

    return State;
  }

  size_t NextEvent{0};
  std::vector<omptest::OmptAssertEvent> Events;
};

/// Class that asserts with set semantics, i.e., unordered
struct OmptEventAsserter : public OmptAsserter {

  void insert(omptest::OmptAssertEvent &&AE) override {
    Events.emplace_back(std::move(AE));
  }

  /// Implements the asserter's logic
  virtual void notifyImpl(omptest::OmptAssertEvent &&AE) override {
    if (!isActive())
      return;

    for (size_t I = 0; I < Events.size(); ++I) {
      if (Events[I] == AE) {
        Events.erase(Events.begin() + I);
        break;
      }
    }
  }

  /// For now use vector (but do set semantics)
  std::vector<omptest::OmptAssertEvent> Events; // TODO std::unordered_set?
};

/// Class that reports the occurred events
class OmptEventReporter : public OmptListener {
public:
  OmptEventReporter(std::ostream &OutStream = std::cout)
      : OutStream(OutStream) {}
  // Called from the CallbackHandler with a corresponding AssertEvent to which
  // callback was handled.
  void notify(omptest::OmptAssertEvent &&AE) override {
    if (!isActive() ||
        (SuppressedEvents.find(AE.getEventType()) != SuppressedEvents.end()))
      return;

    OutStream << AE.toString() << std::endl;
  }

  /// Control whether this asserter should be considered 'active'.
  void setActive(bool Enabled) { Active = Enabled; }

  /// Check if this asserter is considered 'active'.
  bool isActive() { return Active; }

  /// Add the given event type to the set of suppressed events.
  void suppressEvent(omptest::internal::EventTy EvTy) {
    SuppressedEvents.insert(EvTy);
  }

  /// Remove the given event type to the set of suppressed events.
  void permitEvent(omptest::internal::EventTy EvTy) {
    SuppressedEvents.erase(EvTy);
  }

private:
  bool Active{true};
  std::ostream &OutStream;

  // For now we add events to the blacklist to suppress their reports by
  // default. This is necessary because AOMP currently does not handle these
  // events.
  std::set<omptest::internal::EventTy> SuppressedEvents{
      omptest::internal::EventTy::ParallelBegin,
      omptest::internal::EventTy::ParallelEnd,
      omptest::internal::EventTy::ThreadBegin,
      omptest::internal::EventTy::ThreadEnd};
};

#endif

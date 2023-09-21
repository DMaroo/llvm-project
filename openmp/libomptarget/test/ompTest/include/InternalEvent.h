#ifndef OPENMP_LIBOMPTARGET_TEST_OMPTEST_INTERNALEVENT_H
#define OPENMP_LIBOMPTARGET_TEST_OMPTEST_INTERNALEVENT_H

#include <cassert>

namespace omptest {

namespace internal {
/// Enum values are used for comparison of observed and asserted events
/// List is based on OpenMP 5.2 specification, table 19.2 (page 447)
enum class EventTy {
  None, // not part of OpenMP spec, used for implementation
  ThreadBegin,
  ThreadEnd,
  ParallelBegin,
  ParallelEnd,
  TaskCreate,
  TaskSchedule,
  ImplicitTask,
  Target,
  TargetEmi,
  TargetDataOp,
  TargetDataOpEmi,
  TargetSubmit,
  TargetSubmitEmi,
  ControlTool,
  DeviceInitialize,
  DeviceFinalize,
  DeviceLoad,
  DeviceUnload
};

struct InternalEvent {
  EventTy Type;
  EventTy getType() const { return Type; }

  InternalEvent() : Type(EventTy::None) {}
  InternalEvent(EventTy T) : Type(T) {}
  virtual ~InternalEvent() = default;

  virtual bool equals(const InternalEvent *o) const {
    assert(false && "Base class implementation");
    return false;
  };
};

#define event_class_stub(EvTy)                                                 \
  struct EvTy : public InternalEvent {                                         \
    virtual bool equals(const InternalEvent *o) const override;                \
    EvTy() : InternalEvent(EventTy::EvTy) {}                                   \
  };

#define event_class_w_custom_body(EvTy, ...)                                   \
  struct EvTy : public InternalEvent {                                         \
    virtual bool equals(const InternalEvent *o) const override;                \
    __VA_ARGS__                                                                \
  };

// clang-format off
event_class_stub(ThreadBegin)
event_class_stub(ThreadEnd)
event_class_w_custom_body(ParallelBegin,                                       \
  ParallelBegin(int NumThreads) :                                              \
                     InternalEvent(EventTy::ParallelBegin),                    \
                     NumThreads(NumThreads) {}                                 \
  int NumThreads;                                                              \
)
event_class_stub(ParallelEnd)
event_class_stub(TaskCreate)
event_class_stub(TaskSchedule)
event_class_stub(ImplicitTask)
event_class_stub(Target)
event_class_stub(TargetEmi)
event_class_stub(TargetDataOp)
event_class_stub(TargetDataOpEmi)
event_class_stub(TargetSubmit)
event_class_stub(TargetSubmitEmi)
event_class_stub(ControlTool)
event_class_stub(DeviceInitialize)
event_class_stub(DeviceFinalize)
event_class_stub(DeviceLoad)
event_class_stub(DeviceUnload)
// clang-format on

#define event_class_operator_stub(EvTy)                                        \
  bool operator==(const EvTy &a, const EvTy &b) { return true; }

#define event_class_operator_w_body(EvTy, ...)                                 \
  bool operator==(const EvTy &a, const EvTy &b) { __VA_ARGS__ }

// clang-format off
event_class_operator_stub(ThreadBegin)
event_class_operator_stub(ThreadEnd)
event_class_operator_w_body(ParallelBegin,                                     \
return a.NumThreads == b.NumThreads;                                           \
)
event_class_operator_stub(ParallelEnd)
event_class_operator_stub(TaskCreate)
event_class_operator_stub(TaskSchedule)
event_class_operator_stub(ImplicitTask)
event_class_operator_stub(Target)
event_class_operator_stub(TargetEmi)
event_class_operator_stub(TargetDataOp)
event_class_operator_stub(TargetDataOpEmi)
event_class_operator_stub(TargetSubmit)
event_class_operator_stub(TargetSubmitEmi)
event_class_operator_stub(ControlTool)
event_class_operator_stub(DeviceInitialize)
event_class_operator_stub(DeviceFinalize)
event_class_operator_stub(DeviceLoad)
event_class_operator_stub(DeviceUnload)
// clang-format on

/// Template "base" for the cast functions generated in the define_cast_func
/// macro
template <typename To>
const To *cast(const InternalEvent *From) {
  return nullptr;
}

/// Generates template specialization of the cast operation for the specified
/// EvTy as the template parameter
#define define_cast_func(EvTy)                                                 \
  template <> const EvTy *cast(const InternalEvent *From) {                    \
    if (From->getType() == EventTy::EvTy)                                      \
      return static_cast<const EvTy *>(From);                                  \
    return nullptr;                                                            \
  }

// clang-format off
define_cast_func(ThreadBegin)
define_cast_func(ThreadEnd)
define_cast_func(ParallelBegin)
define_cast_func(ParallelEnd)
define_cast_func(TaskCreate)
define_cast_func(TaskSchedule)
define_cast_func(ImplicitTask)
define_cast_func(Target)
define_cast_func(TargetEmi)
define_cast_func(TargetDataOp)
define_cast_func(TargetDataOpEmi)
define_cast_func(TargetSubmit)
define_cast_func(TargetSubmitEmi)
define_cast_func(ControlTool)
define_cast_func(DeviceInitialize)
define_cast_func(DeviceFinalize)
define_cast_func(DeviceLoad)
define_cast_func(DeviceUnload)
// clang-format on

/// Auto generate the equals override to cast and dispatch to the specific class
/// operator==
#define class_equals_op(EvTy)                                                  \
  bool EvTy::equals(const InternalEvent *o) const {                            \
    if (const auto O = cast<EvTy>(o))                                          \
      return *this == *O;                                                      \
    return false;                                                              \
  }

// clang-format off
class_equals_op(ThreadBegin)
class_equals_op(ThreadEnd)
class_equals_op(ParallelBegin)
class_equals_op(ParallelEnd)
class_equals_op(TaskCreate)
class_equals_op(TaskSchedule)
class_equals_op(ImplicitTask)
class_equals_op(Target)
class_equals_op(TargetEmi)
class_equals_op(TargetDataOp)
class_equals_op(TargetDataOpEmi)
class_equals_op(TargetSubmit)
class_equals_op(TargetSubmitEmi)
class_equals_op(ControlTool)
class_equals_op(DeviceInitialize)
class_equals_op(DeviceFinalize)
class_equals_op(DeviceLoad)
class_equals_op(DeviceUnload)
// clang-format on

} // namespace internal

} // namespace omptest

#endif
